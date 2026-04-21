The bug happens because Teleport’s backend “top requests” tracking is **explicitly disabled unless the process is running in debug mode**, so the Prometheus metric that `tctl top` reads never gets any samples in normal runs.

### Code path

1. **Auth storage / cache backends are wrapped in `Reporter`, but tracking is gated by `process.Config.Debug`**
   - Auth backend: `lib/service/service.go:2394-2398`
   - Cache backend: `lib/service/service.go:1322-1326`
   - Both pass:
     ```go
     TrackTopRequests: process.Config.Debug,
     ```
   - So if `--debug` is not set, `TrackTopRequests` is false.

2. **`Reporter.trackRequest` returns immediately when tracking is disabled**
   - `lib/backend/report.go:222-226`
     ```go
     func (s *Reporter) trackRequest(...) {
         if !s.TrackTopRequests {
             return
         }
     ```
   - That means backend operations like `Get`, `Put`, `Delete`, `GetRange`, etc. call `trackRequest(...)` (`lib/backend/report.go:73-191`), but nothing is recorded unless debug mode is on.

3. **The metric exists, but only populated when `trackRequest` runs**
   - The counter vec is declared and registered in `lib/backend/report.go:277-414`.
   - It uses labels derived from the request key:
     - component
     - req
     - range
   - The code even notes the risk of too many distinct requests:
     - `lib/backend/report.go:230-234`
       > “take just the first two parts, otherwise too many distinct requests can end up in the map”

4. **`tctl top` only shows what it finds in the scraped metric**
   - `generateReport` reads `teleport.MetricBackendRequests` and builds the “top backend requests” table:
     - `tool/tctl/common/top_command.go:564-575`
   - `getRequests` returns `nil` if the metric is missing or has no samples:
     - `tool/tctl/common/top_command.go:641-644`
   - Then the UI renders from `SortedTopRequests()`:
     - `tool/tctl/common/top_command.go:145-159`

### Why it appears “empty” without `--debug`

Even though the diagnostic service always serves `/metrics`:
- `lib/service/service.go:1712-1714`

…the backend request counter is never incremented unless debug mode is enabled. So the metrics scrape contains no `backend_requests` samples, `generateReport` sees nothing, and `tctl top` has no backend-request data to display.

### Important detail

There is **no bounded cache / LRU eviction** for these request labels in this code. The only existing protection against unbounded label growth is the debug-mode gate. That’s why the current behavior is:
- safe from cardinality explosion,
- but unusable for `tctl top` unless the Auth Server is started with `--debug`.

If you want, I can also trace where `tctl top` gets its numbers from the `/metrics` endpoint end-to-end.
