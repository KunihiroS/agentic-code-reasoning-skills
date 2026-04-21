Selected mode: **explain**

Step 1: Task and constraints
- Task: identify the repo-side code paths that expose inline SVG email attachments to browser loading, and explain why that can lead to script execution.
- Constraints: static inspection only; no execution; every claim must cite `file:line`.

Step 2: Numbered premises
- **P1:** The issue concerns SVG content in mail attachments / inline images.
- **P2:** The relevant code must therefore be in the mail viewer’s inline-image pipeline or attachment-open pipeline.
- **P3:** The answer must distinguish verified repo behavior from browser behavior outside the repo.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `usePlaceholderForInlineImagesRule` | `src/common/misc/HtmlSanitizer.ts:601-613` | internal rule handler | `RuleResult` | Rewrites `cid:` image sources to a placeholder, stores the CID in `inlineImageCids`, and leaves a marker for later replacement. |
| `MailViewerViewModel.loadAndProcessAdditionalMailInfo` | `src/mail-app/mail/view/MailViewerViewModel.ts:889-946` | `(mail: Mail, delayBodyRenderingUntil: Promise<unknown>) => Promise<string[]>` | `Promise<string[]>` | Loads mail details, sanitizes the mail body, collects referenced inline-image CIDs, and returns them for attachment loading. |
| `MailViewerViewModel.loadAttachments` | `src/mail-app/mail/view/MailViewerViewModel.ts:949-971` | `(mail: Mail, inlineCids: string[]) => Promise<void>` | `Promise<void>` | Downloads decrypted attachments and, if inline images are not yet loaded, calls `loadInlineImages(...)` to build the inline-image map. |
| `getReferencedAttachments` | `src/mail-app/mail/view/MailGuiUtils.ts:576-578` | `(attachments: Array<TutanotaFile>, referencedCids: Array<string>) => Array<TutanotaFile>` | `Array<TutanotaFile>` | Filters attachments down to those whose `cid` matches a referenced inline CID. |
| `loadInlineImages` | `src/mail-app/mail/view/MailGuiUtils.ts:564-573` | `(fileController: FileController, attachments: Array<TutanotaFile>, referencedCids: Array<string>) => Promise<InlineImages>` | `Promise<InlineImages>` | Fetches each referenced attachment as a `DataFile`, sanitizes SVG inline attachments, then creates inline-image references from the resulting bytes. |
| `createInlineImageReference` | `src/mail-app/mail/view/MailGuiUtils.ts:552-561` | `(file: DataFile, cid: string) => InlineImageReference` | `InlineImageReference` | Wraps the file bytes in a `Blob` with `file.mimeType` and creates a browser object URL from that blob. |
| `MailViewer.replaceInlineImages` | `src/mail-app/mail/view/MailViewer.ts:524-546` | `() => Promise<void>` | `Promise<void>` | After the mail body is rendered, calls `replaceCidsWithInlineImages(...)` and wires image context actions to download/open the underlying attachment. |
| `replaceCidsWithInlineImages` | `src/mail-app/mail/view/MailGuiUtils.ts:457-533` | `(dom: HTMLElement, inlineImages: InlineImages, onContext: ...) => Array<{cid: string; url: string}>` | `Array<{cid: string; url: string}>` | Finds `<img cid>` elements and sets their `src` to the inline-image object URL. This is the actual DOM exposure point. |
| `MailViewerViewModel.downloadAndOpenAttachment` | `src/mail-app/mail/view/MailViewerViewModel.ts:1285-1302` | `(file: TutanotaFile, open: boolean) => Promise<void>` | `Promise<void>` | Decrypts the attachment and either downloads it or opens it via `fileController.open(file)`. |
| `FileController.open` | `src/common/file/FileController.ts:139-145` | `(file: DownloadableFileEntity, archiveType?, transferId?) => Promise<DownloadReturn>` | `Promise<DownloadReturn>` | Delegates “open” to `doDownload(..., DownloadPostProcessing.Open, ...)`, i.e. it prepares a file for host/browser opening rather than saving. |
| `openDataFileInBrowser` | `src/common/file/FileController.ts:288-319` | `(dataFile: DataFile) => Promise<void>` | `Promise<void>` | Creates a `Blob` with `dataFile.mimeType` (except a PDF workaround) and opens it via an object URL in a new tab / legacy download flow. |

DATA FLOW ANALYSIS:
- **Variable: `inlineImageCids`**
  - Created at: `HtmlSanitizer.ts:601-613` and returned by `sanitizeFragment` / `sanitizeInlineAttachment` paths.
  - Modified at: `HtmlSanitizer.ts:607`.
  - Used at: `MailViewerViewModel.ts:890-946`, `MailViewerViewModel.ts:1260-1263`, `MailGuiUtils.ts:564-578`.
- **Variable: `loadedInlineImages`**
  - Created at: `MailViewerViewModel.ts:138` as `null`.
  - Modified at: `MailViewerViewModel.ts:969-971`.
  - Used at: `MailViewer.ts:524-546`, `MailViewerViewModel.ts:321-323`, `MailViewerViewModel.ts:266-267`.
- **Variable: `mimeType` in browser open flow**
  - Created at: `FileController.ts:300-304`.
  - Modified at: only the PDF workaround branch changes it; otherwise it stays `dataFile.mimeType`.
  - Used at: `FileController.ts:304-305` to create the blob that the browser opens.

SEMANTIC PROPERTIES:
- **Property 1: Inline `cid:` images are not left as raw text; they are converted into live image elements.**
  - Evidence: `usePlaceholderForInlineImagesRule` rewrites `cid:` to a placeholder and stores the CID (`HtmlSanitizer.ts:601-613`), then `replaceCidsWithInlineImages` sets `img[src]` to the inline object URL (`MailGuiUtils.ts:457-478`).
- **Property 2: The inline-image pipeline preserves SVG as SVG at the blob layer.**
  - Evidence: `loadInlineImages` sanitizes SVG inline attachments but then passes the resulting `DataFile` into `createInlineImageReference`, which builds a `Blob` with `file.mimeType` and an object URL (`MailGuiUtils.ts:564-573`, `552-561`).
- **Property 3: The explicit “open” path preserves the attachment MIME type when handing it to the browser.**
  - Evidence: `openDataFileInBrowser` uses `new Blob([dataFile.data], { type: mimeType })` where `mimeType` is `dataFile.mimeType` unless the PDF workaround applies (`FileController.ts:292-305`).

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I would expect to find a path that rasterizes SVG or strips it down to a non-executable bitmap before any browser load, or a path that forces non-SVG MIME types before opening.
- Searched for: SVG rasterization/conversion and other `sanitizeInlineAttachment` call sites.
- Found: `sanitizeInlineAttachment` is only used in `loadInlineImages()` (`MailGuiUtils.ts:568-571`), and the result is still wrapped as a `Blob` using the original MIME type (`MailGuiUtils.ts:552-561`); the browser-open path also preserves `dataFile.mimeType` (`FileController.ts:288-319`).
- Conclusion: **REFUTED** — there is no repo evidence of rasterization or MIME neutralization in the relevant paths.

FORMAL CONCLUSION:
By **P1** and **P2**, the relevant behavior is in the mail viewer’s inline-image and attachment-open flows.  
By **P3** and the traced code:
- The **inline display path** is:
  `HtmlSanitizer.usePlaceholderForInlineImagesRule` → `MailViewerViewModel.loadAndProcessAdditionalMailInfo` → `MailViewerViewModel.loadAttachments` → `MailGuiUtils.loadInlineImages` → `createInlineImageReference` → `MailViewer.replaceInlineImages` / `replaceCidsWithInlineImages`.
  This path exposes attachment bytes to the DOM as image object URLs (`MailGuiUtils.ts:457-478`, `552-573`).
- The **user-open path** is:
  `MailViewerViewModel.downloadAndOpenAttachment` → `FileController.open` → `openDataFileInBrowser`.
  This path opens the attachment as a browser `Blob` using the original MIME type (`MailViewerViewModel.ts:1285-1302`, `FileController.ts:288-319`).

So the repo-side logic responsible for the reported behavior is the combination of:
1. **CID placeholder replacement + object-URL rendering** for inline images, and
2. **Open-as-original-MIME** handling for the attachment “open” flow.

What remains uncertain is only the browser’s own SVG execution semantics under the user action; that behavior is outside the repository and was not executed here.

**ANSWER:** The code paths above are the ones responsible for exposing inline SVG mail attachments to direct browser loading.

**CONFIDENCE:** MEDIUM
