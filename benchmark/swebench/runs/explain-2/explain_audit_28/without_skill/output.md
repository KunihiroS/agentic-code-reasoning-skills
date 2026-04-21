The root cause is that the normal `tsh login` flow reuses the same kubeconfig-update path that is meant to select a Kubernetes context, and that path explicitly writes `CurrentContext` when a kube cluster is present.

### Code path that causes it

1. **`tsh login` calls kubeconfig update during the login flow**  
   In `onLogin`, the “normal login” branch calls `updateKubeConfigOnLogin(cf, tc)` after a successful login:
   - `tool/tsh/common/tsh.go:2366-2391`

2. **`updateKubeConfigOnLogin` forwards to the general kubeconfig updater**  
   It does not just refresh credentials; it calls `updateKubeConfig(...)`:
   - `tool/tsh/common/tsh.go:6391-6408`

3. **`updateKubeConfig` builds kubeconfig values with `SelectCluster` set from `cf.KubernetesCluster`**  
   The updater passes the selected kube cluster through as:
   - `tool/tsh/common/kube.go:1545-1559`

4. **`kubeconfig.UpdateConfig` changes the active context when `SelectCluster` is non-empty**  
   In the exec-plugin path, it checks that the target context exists and then does:
   - `config.CurrentContext = contextName`
   - `lib/kube/kubeconfig/kubeconfig.go:267-278`

### Why this can happen on `tsh login`

`cf.KubernetesCluster` is populated from the environment if it was not set on the command line:

- `tool/tsh/common/tsh.go:6325-6327`

So, in the current implementation, a login can inherit a kube-cluster selection from `TELEPORT_KUBE_CLUSTER` and then:

- `tsh login` → `updateKubeConfigOnLogin`
- `updateKubeConfig` → `buildKubeConfigUpdate`
- `buildKubeConfigUpdate` sets `SelectCluster`
- `kubeconfig.UpdateConfig` writes `config.CurrentContext = ...`

### Bottom line

The bug is not that kubeconfig is edited at all; it’s that **the regular login path uses the kube-context selection machinery**, and that machinery **unconditionally switches `CurrentContext` whenever `SelectCluster` is set**. Because `cf.KubernetesCluster` can come from env as well as flags, `tsh login` can silently change the active kubectl context instead of merely refreshing Teleport credentials.
