QUESTION: Why does `/api/v3/users/[uid]` return private fields to regular authenticated users, and what code path leads to that behavior?

PREMISES:
P1: The reported endpoint is the v3 API user route mounted under `/api/v3/users`.
P2: The answer must be based on static inspection only, with file:line evidence.
P3: The relevant question is whether the v3 GET path applies the same privacy filtering as the profile/account code paths.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `Write.reload` | `src/routes/write/index.js:24-35` | `(params)` | `Promise<void>` | Mounts `/api/v3/users` to the users subrouter and sets `res.locals.isAPI = true` for v3 requests. |
| `setupApiRoute` | `src/routes/helpers.js:48-53` | `(router, verb, name, middlewares, controller)` | `void` | Adds default API middlewares, then dispatches to the given controller; it does not add user-privacy filtering by itself. |
| `Assert.user` | `src/middleware/assert.js:22-28` | `(req, res, next)` | `void` | Only checks that `req.params.uid` exists; it does not authorize access or hide fields. |
| `Users.get` | `src/controllers/write/users.js:46-48` | `(req, res)` | `void` | Returns `user.getUserData(req.params.uid)` directly via `formatApiResponse`. |
| `User.getUserData` | `src/user/data.js:135-138` | `(uid)` | `Promise<object \| null>` | Returns the first result from `User.getUsersData([uid])`. |
| `User.getUsersData` | `src/user/data.js:140-142` | `(uids)` | `Promise<object[]>` | Calls `User.getUsersFields(uids, [])`, i.e. asks for the default full user field set. |
| `User.getUsersFields` | `src/user/data.js:47-80` | `(uids, fields)` | `Promise<object[]>` | If `fields` is empty, it uses the whitelist, which includes `email` and `fullname`; it has no caller-based privacy decision. |
| `User.getUserDataByUID` | `src/controllers/user.js:56-76` | `(callerUid, uid)` | `Promise<object>` | This is the privacy-aware path: it checks `view:users`, loads settings, and blanks `email` / `fullname` when the target settings or global config require it. |
| `helpers.getUserDataByUserSlug` | `src/controllers/accounts/helpers.js:19-58` | `(userslug, callerUID, query)` | `Promise<object>` | Another privacy-aware path: it blanks `email` / `fullname` for non-self, non-admin, non-global-mod users when visibility is disabled. |

DATA FLOW ANALYSIS:
Variable: `req.params.uid`
  - Created at: `src/routes/write/users.js:21-23`
  - Modified at: NEVER modified in this path
  - Used at: `src/controllers/write/users.js:46-48`, `src/middleware/assert.js:22-28`

Variable: `userData`
  - Created at: `src/controllers/write/users.js:47`
  - Modified at: `src/user/data.js:154-197` inside `modifyUserData`
  - Used at: returned by `Users.get` and serialized to the API response

Variable: `fields`
  - Created at: `src/user/data.js:47`
  - Modified at: `src/user/data.js:54-65`, `src/user/data.js:82-109`
  - Used at: `src/user/data.js:67-79`
  - Key fact: when empty, it becomes the full whitelist, not a privacy-filtered subset

SEMANTIC PROPERTIES:
Property 1: The v3 GET user endpoint is authenticated, but not privacy-aware.
  - Evidence: the route only requires `ensureLoggedIn` plus `Assert.user` (`src/routes/write/users.js:16-23`), and `Assert.user` only checks existence (`src/middleware/assert.js:22-28`).

Property 2: The v3 GET handler returns raw user data, not the privacy-filtered helper output.
  - Evidence: `Users.get` directly calls `user.getUserData(req.params.uid)` (`src/controllers/write/users.js:46-48`), while the privacy-aware helper lives elsewhere (`src/controllers/user.js:56-76`, `src/controllers/accounts/helpers.js:19-58`).

Property 3: `user.getUserData()` expands to a broad whitelist that includes sensitive fields.
  - Evidence: `User.getUserData -> User.getUsersData([uid]) -> User.getUsersFields(uids, [])` (`src/user/data.js:135-142`), and the whitelist contains `email` and `fullname` (`src/user/data.js:22-29`).

Property 4: The code that hides private fields exists, but it is not used by the v3 route.
  - Evidence: `getUserDataByUID` explicitly blanks `email` and `fullname` for non-self / non-admin / non-global-mod callers based on settings and config (`src/controllers/user.js:56-76`), and `getUserDataByUserSlug` does the same (`src/controllers/accounts/helpers.js:19-58`).

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, the v3 route would need to route through a privacy-aware helper or perform a permission check before returning the record.
- Searched for: `canViewUsers`, `checkAccountPermissions`, or `accountHelpers.getUserDataByUserSlug` in the `/api/v3/users/:uid` GET path.
- Found: the v3 GET route is `setupApiRoute(router, 'get', '/:uid', [...middlewares, middleware.assert.user], controllers.write.users.get)` (`src/routes/write/users.js:21-23`), and the controller returns `user.getUserData(req.params.uid)` directly (`src/controllers/write/users.js:46-48`).
- Conclusion: REFUTED — the v3 path does not apply the privacy-aware filtering used elsewhere.

FINAL ANSWER:
The bug occurs because `/api/v3/users/:uid` is wired to the **write API** users router, and its GET handler returns the raw user object without applying the privacy-aware user-profile logic.

Concretely:

1. The v3 API mounts `/api/v3/users` via `Write.reload` (`src/routes/write/index.js:24-35`).
2. The GET route for `/api/v3/users/:uid` only uses `ensureLoggedIn` and `Assert.user` (`src/routes/write/users.js:16-23`).
3. `Assert.user` only verifies that the target uid exists; it does **not** check whether the caller may view private fields (`src/middleware/assert.js:22-28`).
4. The controller then does `helpers.formatApiResponse(200, res, await user.getUserData(req.params.uid))` (`src/controllers/write/users.js:46-48`).
5. `user.getUserData()` expands to `User.getUsersData([uid])`, which calls `User.getUsersFields(uids, [])` (`src/user/data.js:135-142`).
6. With an empty field list, `User.getUsersFields()` uses the full whitelist, and that whitelist includes `email` and `fullname` (`src/user/data.js:22-29`, `src/user/data.js:47-65`).

So the endpoint returns private fields because it uses a **generic data loader** that exposes the whitelisted fields, rather than the **privacy-filtered** code path that blanks `email` and `fullname` based on self/admin/global-moderator status and the target user’s visibility settings (`src/controllers/user.js:56-76`, `src/controllers/accounts/helpers.js:19-58`).

In short: the bug is a **missing privacy filter on the `/api/v3/users/:uid` GET path**, not a problem in the field database itself.

CONFIDENCE: HIGH
