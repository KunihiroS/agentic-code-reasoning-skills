The bug comes from the fact that **reference removal and snapshot cleanup are split apart**, and `Delete()` only removes one of them.

### Code path

1. **The git snapshot store tries to prune stale refs by calling `Delete()`**
   - In `SnapshotStore.update()`, the cache is scanned and any ref missing from the remote is passed to `s.snaps.Delete(ref)`:
   - `internal/storage/fs/git/store.go:344-360`

2. **`SnapshotCache.Delete()` only removes the ref from the LRU index**
   - It rejects fixed refs outright:
     - `internal/storage/fs/cache.go:179-181`
   - For non-fixed refs, it only does:
     - `c.extra.Remove(ref)` at `internal/storage/fs/cache.go:182-184`
   - **It does not evict the underlying snapshot from `c.store`**.

3. **The only code that actually removes snapshot data is `evict()`**
   - `evict()` deletes `c.store[k]` when a key is no longer referenced:
     - `internal/storage/fs/cache.go:188-207`
   - But `Delete()` does not call `evict()` in the buggy version, so deleting a ref leaves its snapshot payload behind.

4. **That stale snapshot can still be reused later**
   - `getByRefAndKey()` checks `c.store[k]` first:
     - `internal/storage/fs/cache.go:139-148`
   - So even after a non-fixed ref is removed from `extra`, the snapshot remains cached by key and can be reused without rebuilding if the same key is requested again.

### Why this causes the reported behavior

- **Fixed refs** are intentionally protected by `Delete()` and remain accessible:
  - `internal/storage/fs/cache.go:179-181`
- **Non-fixed refs** can be removed from the ref index, but the snapshot they pointed at is not reclaimed:
  - `internal/storage/fs/cache.go:182-184`
  - `internal/storage/fs/cache.go:188-207`

So the cache had **no controlled way to fully delete a non-fixed reference and its backing snapshot**, while fixed refs were permanently protected. That is why references could not be selectively cleaned up as expected.
