Selected mode: **explain**

QUESTION: Why does `tsh login` change the active `kubectl` context, and what in the code causes it?

PREMISES:
P1: The reported behavior happens immediately after `tsh login` on a cluster where Teleport advertises Kubernetes support.
P2: The `tsh login` flow in `tool/tsh/tsh.go` explicitly calls `kubeconfig.UpdateWithClient(...)` when `tc.KubeProxyAddr != ""`.
P3: `UpdateWithClient(...)` builds kubeconfig data, fetches Kubernetes cluster names, chooses a default cluster with `CheckOrSetKubeCluster(...)`, and then delegates to `Update(...)`.
P4: `Update(...)` writes the kubeconfig back to disk and sets `config.CurrentContext` when it is generating Teleport kubeconfig entries.
P5: `CheckOrSetKubeCluster(...)` defaults to the Teleport cluster name if present, otherwise the first Kubernetes cluster alphabetically.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `onLogin` | `tool/tsh/tsh.go:657` | `(*CLIConf)` | `error` | After successful login, if `tc.KubeProxyAddr != ""`, it calls `kubeconfig.UpdateWithClient(...)`, so login can rewrite kubeconfig. |
| `UpdateWithClient` | `lib/kube/kubeconfig/kubeconfig.go:69` | `(context.Context, string, *client.TeleportClient, string)` | `error` | Reads Teleport credentials, checks Kubernetes support, fetches k8s clusters, computes `Exec.SelectCluster`, and calls `Update(...)`. |
| `KubeClusterNames` | `lib/kube/utils/utils.go:154` | `(context.Context, KubeServicesPresence)` | `([]string, error)` | Returns a sorted unique list of registered Kubernetes cluster names. |
| `CheckOrSetKubeCluster` | `lib/kube/utils/utils.go:177` | `(context.Context, KubeServicesPresence, string, string)` | `(string, error)` | If no kube cluster was specified, returns the Teleport cluster name when available, otherwise the first cluster alphabetically. |
| `Update` | `lib/kube/kubeconfig/kubeconfig.go:136` | `(string, Values)` | `error` | Loads kubeconfig, writes Teleport cluster/auth/context entries, sets `config.CurrentContext` either to the selected kube context or to the Teleport cluster name, then saves to disk. |
| `Save` | `lib/kube/kubeconfig/kubeconfig.go:268` | `(string, clientcmdapi.Config)` | `error` | Resolves the kubeconfig file path and writes the modified config to disk. |

DATA FLOW ANALYSIS:
Variable: `v.Exec.SelectCluster`
- Created at: `lib/kube/kubeconfig/kubeconfig.go:94-97` as part of `ExecValues`
- Modified at: `lib/kube/kubeconfig/kubeconfig.go:115` from `kubeutils.CheckOrSetKubeCluster(...)`
- Used at: `lib/kube/kubeconfig/kubeconfig.go:174-179` to assign `config.CurrentContext`

Variable: `config.CurrentContext`
- Created/loaded at: `lib/kube/kubeconfig/kubeconfig.go:137` by `Load(path)`
- Modified at: `lib/kube/kubeconfig/kubeconfig.go:179` when `Exec.SelectCluster != ""`
- Modified at: `lib/kube/kubeconfig/kubeconfig.go:199` in the non-exec fallback path
- Used at: `lib/kube/kubeconfig/kubeconfig.go:202` when `Save(...)` persists the change

Variable: kubeconfig file on disk
- Created/loaded at: `lib/kube/kubeconfig/kubeconfig.go:268-275`
- Modified at: `lib/kube/kubeconfig/kubeconfig.go:202` via `Save(...)`
- Observed by `kubectl` afterward because `kubectl` reads the same kubeconfig file

SEMANTIC PROPERTIES:
Property 1: `tsh login` is not “authentication only” when Kubernetes is enabled.
- Evidence: `tool/tsh/tsh.go:795-799` calls `kubeconfig.UpdateWithClient(...)` during login.

Property 2: the kubeconfig helper is designed to choose an active Kubernetes context.
- Evidence: `lib/kube/kubeconfig/kubeconfig.go:174-180` assigns `config.CurrentContext = contextName`.

Property 3: the default chosen context is not necessarily the one the user had before login.
- Evidence: `lib/kube/utils/utils.go:188-197` defaults to the Teleport cluster name or the first cluster alphabetically.

Property 4: the mutation is persisted, so `kubectl` immediately sees it.
- Evidence: `lib/kube/kubeconfig/kubeconfig.go:202` calls `Save(...)`, and `Save(...)` writes the file at `lib/kube/kubeconfig/kubeconfig.go:268-275`.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, the context change would have to come from `kubectl` itself or from some unrelated side effect, not from `tsh login`.
- Searched for: writes to `CurrentContext` on the `tsh login` path and the helper functions it calls.
- Found: `onLogin` invokes `UpdateWithClient` at `tool/tsh/tsh.go:795-799`; `Update` assigns `config.CurrentContext` at `lib/kube/kubeconfig/kubeconfig.go:174-180` and `:198-199`; `Save` persists it at `:202` and `:268-275`.
- Conclusion: REFUTED. The context switch is directly caused by Teleport’s kubeconfig update logic, not by `kubectl`.

FINAL ANSWER:
The root cause is that `tsh login` is currently wired to **rewrite the user’s kubeconfig whenever the proxy advertises Kubernetes support**. In `tool/tsh/tsh.go:795-799`, the login flow calls `kubeconfig.UpdateWithClient(...)`. That helper then computes a Kubernetes target (`lib/kube/kubeconfig/kubeconfig.go:93-126`), and `Update(...)` explicitly sets `config.CurrentContext` before saving the file (`lib/kube/kubeconfig/kubeconfig.go:174-180`, `:198-202`).

So the behavior is intentional in the current implementation: `tsh login` does not just store credentials; it also updates kubeconfig and makes one Teleport-generated context current. The selected context is determined by `CheckOrSetKubeCluster(...)` (`lib/kube/utils/utils.go:177-197`), which prefers the Teleport cluster name or else the first Kubernetes cluster alphabetically. That is why `kubectl config get-contexts` changes after login.

By P2, P3, P4, and P5, the codebase’s current implementation **does** mutate the active kubectl context during `tsh login` when Kubernetes support is present, and it persists that mutation to disk. The remaining uncertainty is only which specific context is chosen in a given environment; the fact that the context changes is fully established.

CONFIDENCE: **HIGH**
