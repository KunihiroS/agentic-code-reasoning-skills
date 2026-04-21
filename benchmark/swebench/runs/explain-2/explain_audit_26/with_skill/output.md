Selected mode: **explain**

QUESTION: Why the snapshot cache bug occurs, and what code path leads to it.

### Step 1: Task and constraints
- Static inspection only.
- Need file:line evidence.
- Must trace the read/update path that keeps references around.

### Step 2: Numbered premises
P1: `SnapshotCache` distinguishes fixed refs from extra refs and has an internal `Delete(ref)` method.  
P2: The public snapshot-store abstraction exposes only `View`, not deletion.  
P3: `SnapshotStore.update()` only deletes refs in a narrow `fetchErr != nil` branch.  
P4: `SnapshotStore.View()` adds or rebuilds refs, but does not remove them.  
P5: The base reference is inserted as fixed, so it is protected from deletion.

### Function trace table
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `NewSnapshotCache` | `internal/storage/fs/cache.go:43-55` | Builds a cache with `fixed`, `extra` (LRU), and `store` maps. | Establishes the two-tier ref model. |
| `AddFixed` | `internal/storage/fs/cache.go:58-68` | Stores a ref in `fixed` and snapshots in `store`; fixed refs are non-evictable. | Base ref is protected. |
| `AddOrBuild` | `internal/storage/fs/cache.go:70-117` | Adds/updates refs; extra refs go into the LRU, fixed refs stay fixed, and old snapshots may be evicted. | This is the main “add/update” path. |
| `Get` | `internal/storage/fs/cache.go:119-137` | Resolves a ref via `fixed` first, then `extra`, then `store`. | Shows refs persist until explicitly removed/evicted. |
| `Delete` | `internal/storage/fs/cache.go:174-185` | Errors for fixed refs; removes extra refs from the LRU. | Confirms selective deletion exists only inside the cache. |
| `ReferencedSnapshotStore` | `internal/storage/fs/store.go:23-33` | Exposes only `View(ctx, ref, fn)`; no delete method. | Explains why callers cannot remove refs through the public API. |
| `SingleReferenceSnapshotStore.View` | `internal/storage/fs/store.go:55-71` | Logs if a non-empty ref is passed, then drops the ref and delegates. | Reinforces that the store layer is read-oriented. |
| `SnapshotStore.NewSnapshotStore` | `internal/storage/fs/git/store.go:134-146, 241-246` | Creates the cache, builds the base snapshot, and stores the base ref as fixed. | Base ref becomes protected. |
| `SnapshotStore.View` | `internal/storage/fs/git/store.go:263-295` | If cache miss, it fetches, resolves, and then `AddOrBuild`s the ref. It never deletes refs. | Main read path only adds/updates. |
| `SnapshotStore.update` | `internal/storage/fs/git/store.go:337-380` | Calls `Delete(ref)` only inside the `if fetchErr != nil` branch and skips `baseRef`. | The only deletion path is error-gated and internal. |
| `SnapshotStore.fetch` | `internal/storage/fs/git/store.go:383-413` | Fetches only the current `s.snaps.References()` set. | Stale refs can keep being reused because the fetch set comes from the cache itself. |

### Data flow analysis
Variable: `s.snaps`
- Created at: `internal/storage/fs/git/store.go:146`
- Modified at:
  - `AddFixed` (`cache.go:62-68`)
  - `AddOrBuild` (`cache.go:73-117`)
  - `Delete` (`cache.go:174-185`)
  - `update` prune path (`git/store.go:344-364`)
- Used at:
  - `View` (`git/store.go:269-290`)
  - `update` (`git/store.go:338-380`)
  - `fetch` via `s.snaps.References()` (`git/store.go:338`, `383-413`)

Variable: `ref`
- Created at: `git/store.go:264-267`
- Modified at: none
- Used at: cache lookup/build in `View` (`git/store.go:269-290`)

Variable: `fixed`
- Created at: `cache.go:44-48`
- Modified at: `AddFixed` and fixed-ref updates in `AddOrBuild` (`cache.go:62-68`, `94-98`)
- Used at: `Get`, `Delete`, `evict`, `References` (`cache.go:119-137`, `174-185`, `198-205`, `166-171`)

### Semantic properties
Property 1: The public storage API is read-only.
- Evidence: `ReferencedSnapshotStore` exposes only `View` (`store.go:23-33`).

Property 2: Deletion is possible only inside `SnapshotCache`, not through the public store interface.
- Evidence: `Delete` exists in `cache.go:174-185`, but no corresponding method exists on `ReferencedSnapshotStore` (`store.go:23-33`), and the only production call site is `git/store.go:356-359`.

Property 3: The base ref is protected.
- Evidence: `NewSnapshotStore` stores the base ref with `AddFixed` (`git/store.go:241-244`), and `Delete` rejects fixed refs (`cache.go:179-180`).

### Hypothesis exploration
HYPOTHESIS H1: The bug happens because the cache has no deletion path at all.  
- Refuted: `SnapshotCache.Delete` exists (`cache.go:174-185`).

HYPOTHESIS H2: The bug happens because callers can’t reach `Delete`.  
- Supported: the exposed store interface only has `View` (`store.go:23-33`), and the only production `Delete` call is the internal prune path in `update` (`git/store.go:344-364`).

HYPOTHESIS H3: The bug happens because stale refs are only pruned on fetch errors.  
- Supported: `update()` deletes refs only when `fetchErr != nil` (`git/store.go:344-364`). In the normal success path, refs are only resolved and rebuilt (`git/store.go:366-380`), not removed.

### Alternative hypothesis check
If the opposite were true — that selective deletion was available through the normal snapshot-store path — I would expect:
- a `Delete` method on `ReferencedSnapshotStore`, or
- more production call sites of `SnapshotCache.Delete`, or
- deletion logic in `SnapshotStore.View()` / `update()` outside the error branch.

I searched for that pattern:
- `ReferencedSnapshotStore` has only `View` (`internal/storage/fs/store.go:23-33`)
- `Delete` is called only once in production code (`internal/storage/fs/git/store.go:356-359`)
- `View()` never deletes refs (`internal/storage/fs/git/store.go:263-295`)

Conclusion: the opposite is **refuted**.

### Formal conclusion
By P1 and P5, the cache is designed to treat the base ref as fixed and non-deletable. By P2 and P4, the normal snapshot-store API only supports reading and adding/updating refs, not removing them. By P3, deletion is only attempted in the internal `update()` prune path, and only when fetch fails. Therefore, the bug occurs because the only general ref-management path is additive, while deletion is both hidden from callers and gated behind an error-only maintenance branch.

So the problematic behavior comes from this code path:

`Store`/`ReferencedSnapshotStore.View()` → `SnapshotStore.View()` → `SnapshotCache.AddOrBuild()`  
with deletion only happening later in `SnapshotStore.update()` when `fetchErr != nil`.

That means non-fixed refs can linger in the cache unless that specific prune branch runs, while fixed refs remain protected by design.

CONFIDENCE: **MEDIUM-HIGH**
