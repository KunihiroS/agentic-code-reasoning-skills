The bug happens because the `getUpvoters` socket method never performs any authorization check before returning vote data.

### Code path

1. **Client requests upvoters on hover**
   - The topic vote UI emits `posts.getUpvoters` with the post id:
   - `public/src/client/topic/votes.js:27-45`
   - Specifically:
     - `socket.emit('posts.getUpvoters', [pid], ...)` at **line 38**

2. **Server receives the socket call**
   - The handler is `SocketPosts.getUpvoters` in `src/socket.io/posts/votes.js`
   - It only checks that the argument is an array:
     - `src/socket.io/posts/votes.js:38-41`
   - Then it immediately calls:
     - `posts.getUpvotedUidsByPids(pids)` at **line 42**
   - There is **no** call to:
     - `privileges.categories.isAdminOrMod(...)`
     - `privileges.posts.can('topics:read', ...)`
     - any other read-permission check

3. **Vote UIDs are fetched directly from storage**
   - `posts.getUpvotedUidsByPids` simply builds Redis set keys and reads them:
   - `src/posts/votes.js:97-98`
   - It does:
     - `db.getSetsMembers(pids.map(pid => \`pid:${pid}:upvote\`))`
   - This is a raw data fetch with no access control.

### Why this bypasses read privileges

The server method returns upvoter usernames based only on the post id(s), not on whether the caller may read the topic/category containing those posts. Since the handler never checks category/topic read access, a user who lacks `topics:read` can still invoke it directly and receive the upvoter list.

### Contrast with the checked path

The same file shows the intended pattern for vote visibility in `getVoters`:

- `src/socket.io/posts/votes.js:10-18`
- That method **does** verify permissions with:
  - `privileges.categories.isAdminOrMod(data.cid, socket.uid)`
  - and a public-vote setting (`meta.config.votesArePublic`)

`getUpvoters` has no equivalent guard, so it exposes the upvote set even when the caller should be blocked.

### Short root cause

**Root cause:** `SocketPosts.getUpvoters` is missing the read-privilege check entirely, and the downstream helper `posts.getUpvotedUidsByPids` reads vote sets directly from the database.
