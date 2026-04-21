QUESTION: Why does `getUpvoters` return upvoter data even when the requester lacks read privileges, and what code path causes that?

### Step 1: Task and constraints
- Task: statically trace the code path for `getUpvoters` and explain the missing authorization.
- Constraints: no execution, use file:line evidence only, and do not speculate beyond the traced code.

### Step 2: Numbered premises
P1: The bug report says `getUpvoters` should be restricted by topic/category read permissions, but currently is not.  
P2: `src/socket.io/posts/votes.js` defines the socket method `SocketPosts.getUpvoters`.  
P3: `src/posts/votes.js` defines `Posts.getUpvotedUidsByPids` as a raw lookup of `pid:*:upvote` sets.  
P4: `src/socket.io/posts.js` contains a nearby post-related method that *does* enforce `topics:read`, showing the intended permission pattern.  
P5: `User.getUsernamesByUids` turns UIDs into usernames via `User.getUsersFields`.  
P6: `db.getSetsMembers` is a pure batch set-membership read with no authorization logic.

---

## Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: `getUpvoters` is missing the permission check entirely.  
EVIDENCE: P1 and the source of `SocketPosts.getUpvoters` should show whether it consults `privileges` or `topics`.  
CONFIDENCE: high

HYPOTHESIS H2: The data helper only reads vote sets, so the bug is not there.  
EVIDENCE: P3 and P6 suggest the helper is just data access.  
CONFIDENCE: high

HYPOTHESIS H3: There is a contrasting method in the same area that shows the expected `topics:read` gate.  
EVIDENCE: P4.  
CONFIDENCE: high

---

## Step 4: Interprocedural trace table

| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|---|---:|---|---|---|
| `SocketPosts.getUpvoters` | `src/socket.io/posts/votes.js:38-59` | `(socket, pids:Array)` | `Promise<Array<{otherCount, usernames}>>` | Only checks `Array.isArray(pids)`, then fetches upvoter UIDs and maps them to usernames. It does **not** inspect `socket.uid`, `topics`, `categories`, or `privileges`. |
| `Posts.getUpvotedUidsByPids` | `src/posts/votes.js:97-99` | `(pids:Array)` | `Promise<Array<Array<Uid>>>` | Returns `db.getSetsMembers(pids.map(pid => \`pid:${pid}:upvote\`))`; pure vote-set lookup. |
| `db.getSetsMembers` | `src/database/redis/sets.js:70-73` | `(keys:Array<String>)` | `Promise<Array<Array<Member>>>` | Batches `smembers` for each key and returns the results; no auth checks. |
| `User.getUsernamesByUids` | `src/user/index.js:115-117` | `(uids:Array<Uid>)` | `Promise<Array<String>>` | Loads user records for those UIDs and returns the `username` field. |
| `User.getUsersFields` | `src/user/data.js:47-83` | `(uids, fields)` | `Promise<Array<UserObj>>` | Normalizes UIDs, whitelists fields, reads `user:*` objects from DB; no topic/category permission logic. |
| `SocketPosts.getPostTimestampByIndex` | `src/socket.io/posts.js:49-65` | `(socket, data)` | `Promise<timestamp>` | Demonstrates the intended pattern: it resolves the post, then checks `privileges.topics.get(...)[ 'topics:read' ]` and throws `[[error:no-privileges]]` if missing. |

### Observations
OBSERVATIONS from `src/socket.io/posts/votes.js`:
- O1: `getVoters` has an explicit authorization gate: `meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid)`; otherwise it throws `[[error:no-privileges]]`. (`src/socket.io/posts/votes.js:10-35`)
- O2: `getUpvoters` has no comparable gate; after the array check it immediately calls `posts.getUpvotedUidsByPids(pids)`. (`src/socket.io/posts/votes.js:38-59`)

OBSERVATIONS from `src/posts/votes.js`:
- O3: `Posts.getUpvotedUidsByPids` is just `db.getSetsMembers(pids.map(pid => \`pid:${pid}:upvote\`))`. (`src/posts/votes.js:97-99`)

OBSERVATIONS from `src/database/redis/sets.js`:
- O4: `db.getSetsMembers` only issues `smembers` commands in batch. (`src/database/redis/sets.js:70-73`)

OBSERVATIONS from `src/user/index.js` and `src/user/data.js`:
- O5: `User.getUsernamesByUids` merely maps UIDs to usernames through `User.getUsersFields`. (`src/user/index.js:115-117`)
- O6: `User.getUsersFields` reads user objects from `user:${uid}` keys after field whitelisting; it does not inspect read privileges for posts/categories. (`src/user/data.js:47-83`)

OBSERVATIONS from `src/socket.io/posts.js`:
- O7: `SocketPosts.getPostTimestampByIndex` explicitly checks `topics:read` before returning post data, proving the module already knows how to enforce read privilege. (`src/socket.io/posts.js:49-65`)

HYPOTHESIS UPDATE:
- H1: CONFIRMED — `getUpvoters` omits authorization entirely.
- H2: CONFIRMED — the helper path is raw data access.
- H3: CONFIRMED — nearby code shows the expected read gate pattern.

UNRESOLVED:
- I did not inspect a separate transport/router ACL that might sit outside these functions.
- That said, the bug still exists in this method body because it performs no read check itself.

---

## Step 5: Refutation check

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, the code path would need evidence of one of these:
1. a `topics:read` / category read check in `getUpvoters`, or
2. an upstream wrapper that blocks unauthorized callers before `getUpvoters` runs.

- Searched for: `getUpvoters` authorization logic and `topics:read`/`privileges` checks in the `getUpvoters` path.
- Found:
  - `src/socket.io/posts/votes.js:38-59` — `getUpvoters` only validates array shape and then fetches vote data.
  - `src/posts/votes.js:97-99` — raw upvote-set lookup.
  - `src/socket.io/posts.js:49-65` — the same module does enforce `topics:read` in a different method, so the omission here is meaningful.
- Conclusion: the opposite answer is REFUTED by the inspected source.

---

## Step 6: Formal conclusion

By P1, P2, P3, P4, P5, and P6, the bug occurs because `SocketPosts.getUpvoters` is an authorization-free data path:

1. The socket method `getUpvoters` accepts `pids` and only checks that the argument is an array. (`src/socket.io/posts/votes.js:38-40`)
2. It then directly calls `Posts.getUpvotedUidsByPids(pids)`, which is just a batch read of `pid:${pid}:upvote` sets. (`src/socket.io/posts/votes.js:42`, `src/posts/votes.js:97-99`)
3. Those UIDs are converted to usernames through `User.getUsernamesByUids` and `User.getUsersFields`, which are also pure data lookups. (`src/socket.io/posts/votes.js:47-57`, `src/user/index.js:115-117`, `src/user/data.js:47-83`)
4. No step in that chain checks `socket.uid`, `topics:read`, category permissions, or admin/mod status.
5. A nearby method in the same socket module shows the intended pattern: it resolves the post and explicitly checks `topics:read` before returning data. (`src/socket.io/posts.js:49-65`)

So the root cause is the missing read-permission gate in `SocketPosts.getUpvoters` itself. That is why a guest or other non-privileged caller can still retrieve upvoter information for posts they should not be allowed to read.

ANSWER: NO — the current implementation is not enforcing the required read privilege for `getUpvoters`.  
CONFIDENCE: HIGH
