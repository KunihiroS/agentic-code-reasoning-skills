The relevant behavior comes from two separate paths: the **sanitized inline preview path** and the **raw attachment open/download path**.

### 1) Inline SVGs are sanitized for display, but only for the preview blob
When the mail body is loaded, inline attachments are fetched and sanitized before being turned into blob URLs:

- `src/mail-app/mail/view/MailViewerViewModel.ts:967-971`  
  `loadAttachments()` loads attachments, then calls `loadInlineImages(...)` for referenced cids.
- `src/mail-app/mail/view/MailGuiUtils.ts:564-573`  
  `loadInlineImages()` does:
  - `fileController.getAsDataFile(file)`
  - `getHtmlSanitizer().sanitizeInlineAttachment(dataFile)`
  - `createInlineImageReference(...)`
- `src/common/misc/HtmlSanitizer.ts:206-229`  
  `sanitizeInlineAttachment()` specifically re-parses `image/svg+xml` as SVG/XML and sanitizes the `<svg>` markup before it is used in the mail body.

That sanitized blob is then assigned to the `<img>` element:

- `src/mail-app/mail/view/MailGuiUtils.ts:475-478`  
  `replaceCidsWithInlineImages()` sets `imageElement.setAttribute("src", inlineImage.objectUrl)`.

### 2) The risky path is the “open/download attachment” action for the same inline image
The inline image UI also exposes actions that do **not** reuse the sanitized blob. The context menu callback resolves the cid back to the **raw attachment** and opens/downloads that file:

- `src/mail-app/mail/view/MailViewer.ts:524-540`  
  The image’s context menu calls `this.viewModel.downloadAndOpenAttachment(inlineAttachment, ...)`.
- `src/mail-app/mail/view/MailViewer.ts:528-539`  
  `inlineAttachment` comes from `this.viewModel.getAttachments()`, i.e. the attachment entity, not the sanitized inline-image blob.

Then:

- `src/mail-app/mail/view/MailViewerViewModel.ts:1285-1292`  
  `downloadAndOpenAttachment()` passes that raw file to `this.fileController.open(file)` or `download(file)`.

In the browser implementation, “open”/download ultimately creates a Blob using the file’s original MIME type:

- `src/common/file/FileController.ts:288-319`  
  `openDataFileInBrowser()` does `new Blob([dataFile.data], { type: mimeType })` and `URL.createObjectURL(blob)`.  
  The only special-case is PDF; SVG keeps its original MIME type.
- `src/common/file/FileControllerBrowser.ts:26-33, 39-41`  
  Browser “open” just routes back to `openDataFileInBrowser()`.

### Why this is the problem
So the key issue is:

- **Preview rendering** of inline SVGs goes through `sanitizeInlineAttachment()`.
- But the **open/download action** for that same inline image bypasses that sanitized blob and reopens the **raw SVG attachment**.
- `openDataFileInBrowser()` preserves `image/svg+xml`, so if the browser loads that SVG directly, it is treated as an SVG document, not as inert bitmap data.

In short, the vulnerable code path is:

`MailViewer` inline image context menu → `MailViewerViewModel.downloadAndOpenAttachment()` → `FileController.open()` → `openDataFileInBrowser()` with original `image/svg+xml`

while the safe preview path is separate:

`loadInlineImages()` → `sanitizeInlineAttachment()` → `replaceCidsWithInlineImages()`.

If you want, I can also trace the exact mail-body sanitization path that inserts the `cid` placeholders in the first place.
