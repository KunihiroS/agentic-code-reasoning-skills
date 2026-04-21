QUESTION: What is the root cause of the issue, and how does the current implementation lead to resource exhaustion on HTTP body reads?

STEP 1 — TASK AND CONSTRAINTS
- Static inspection only; no code execution.
- Need file:line evidence.
- Focus on HTTP request/response body reads and any shared helper used by them.

STEP 2 — NUMBERED PREMISES
P1: The issue is about unbounded HTTP request and response body reads causing memory/resource exhaustion.
P2: The current tree must be inspected for actual body-reading code paths and any size-limiting helper.
P3: A bounded-read fix would need either an explicit limit (`io.LimitReader`, `http.MaxBytesReader`, etc.) or a shared helper that enforces one.
P4: If no such limit exists on the relevant paths, large bodies will be fully buffered into memory before parsing or error handling.

STEP 3 — HYPOTHESIS-DRIVEN EXPLORATION

HYPOTHESIS H1: The root cause is direct `ReadAll` usage on HTTP bodies with no size cap.
EVIDENCE: Search results show `ioutil.ReadAll` on `r.Body` / `resp.Body` in multiple production HTTP paths.
CONFIDENCE: high

OBSERVATIONS from `lib/httplib/httplib.go`:
  O1: `ReadJSON` does `data, err := ioutil.ReadAll(r.Body)` and then `json.Unmarshal(data, &val)` at `lib/httplib/httplib.go:110-117`.
  O2: There is no `io.LimitReader` / `http.MaxBytesReader` / `ReadAtMost` in this function.
HYPOTHESIS UPDATE:
  H1: CONFIRMED — the shared request-body helper is unbounded.
UNRESOLVED:
  - Which call sites inherit this behavior?
NEXT ACTION RATIONALE: Check representative handlers that call `ReadJSON`.

OBSERVATIONS from `lib/auth/apiserver.go` and `lib/web/users.go`:
  O3: `postSessionSlice` reads the whole request body with `ioutil.ReadAll(r.Body)` at `lib/auth/apiserver.go:1903-1910`.
  O4: `createUser` and `updateUser` both call `httplib.ReadJSON(r, &req)` at `lib/web/users.go:74-88` and `lib/web/users.go:106-120`, so they inherit the unbounded read.
HYPOTHESIS UPDATE:
  H1: CONFIRMED — multiple request handlers consume the entire body before validation/parsing.
UNRESOLVED:
  - Which response-body readers are similarly unbounded?
NEXT ACTION RATIONALE: Inspect representative response-body readers used by internal HTTP clients.

OBSERVATIONS from `lib/auth/github.go`, `lib/auth/oidc.go`, `lib/services/saml.go`, `lib/kube/proxy/roundtrip.go`, `lib/srv/db/aws.go`, `lib/auth/clt.go`:
  O5: `githubAPIClient.get` reads the full response body with `ioutil.ReadAll(response.Body)` before returning bytes / error text at `lib/auth/github.go:654-668`.
  O6: `gsuiteClient.fetchGroupsPage` reads the full response body with `ioutil.ReadAll(resp.Body)` before status handling / JSON unmarshal at `lib/auth/oidc.go:704-736`.
  O7: `ValidateSAMLConnector` reads the full fetched descriptor body with `ioutil.ReadAll(resp.Body)` at `lib/services/saml.go:43-61`.
  O8: `SpdyRoundTripper.NewConnection` reads the full error response body with `ioutil.ReadAll(resp.Body)` on non-upgrade responses at `lib/kube/proxy/roundtrip.go:207-221`.
  O9: `downloadRDSRootCert` reads the full response body with `ioutil.ReadAll(resp.Body)` at `lib/srv/db/aws.go:78-93`.
  O10: `Client.PostSessionSlice` reads the full response body with `ioutil.ReadAll(re.Body)` before returning `trace.ReadError` at `lib/auth/clt.go:1611-1630`.
HYPOTHESIS UPDATE:
  H1: CONFIRMED — the codebase has several unbounded response-body reads too.
UNRESOLVED:
  - Is there any shared helper or limit elsewhere that prevents these reads from becoming large allocations?
NEXT ACTION RATIONALE: Search for a bounded-read helper or limit enforcement.

OBSERVATIONS from repository search:
  O11: `rg -n "ReadAtMost" lib` returned no matches.
  O12: `rg -n "MaxBytesReader|LimitReader" . --glob '!vendor/**'` found bounded reads only in unrelated code paths like `lib/pam/pam.go:473` and `lib/events/auditlog.go:868`, not in these HTTP helpers.
HYPOTHESIS UPDATE:
  H1: CONFIRMED — there is no shared bounded-read helper in this tree for these HTTP paths.
HYPOTHESIS H2: The issue is systemic: the affected code paths buffer entire HTTP bodies into memory before parsing or error handling.
EVIDENCE: O1, O3, O5-O10, O11, O12.
CONFIDENCE: high

STEP 4 — INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `httplib.ReadJSON` | `lib/httplib/httplib.go:110-117` | `(*http.Request, interface{})` | `error` | Reads the entire `r.Body` with `ioutil.ReadAll`, then unmarshals the full byte slice; no size limit is applied. |
| `(*APIServer).postSessionSlice` | `lib/auth/apiserver.go:1903-1910` | `(ClientI, http.ResponseWriter, *http.Request, httprouter.Params, string)` | `(interface{}, error)` | Reads the full request body into memory and unmarshals it as `events.SessionSlice`. |
| `createUser` | `lib/web/users.go:74-88` | `(*http.Request, userAPIGetter, string)` | `(*ui.User, error)` | Calls `httplib.ReadJSON`, so it inherits the unbounded request-body read before creating the user. |
| `updateUser` | `lib/web/users.go:106-120` | `(*http.Request, userAPIGetter, string)` | `(*ui.User, error)` | Calls `httplib.ReadJSON`, so it inherits the unbounded request-body read before updating the user. |
| `(*githubAPIClient).get` | `lib/auth/github.go:654-668` | `(string)` | `([]byte, string, error)` | Performs an HTTP GET, closes the response body, then reads the entire body with `ioutil.ReadAll` before status/error handling. |
| `(*gsuiteClient).fetchGroupsPage` | `lib/auth/oidc.go:704-736` | `(string)` | `(*gsuiteGroups, error)` | Performs an HTTP GET, closes the response body, then reads the entire body with `ioutil.ReadAll` before status handling and JSON parsing. |
| `ValidateSAMLConnector` | `lib/services/saml.go:43-61` | `(SAMLConnector)` | `error` | Fetches the entity descriptor URL, then reads the full response body into a string with `ioutil.ReadAll`. |
| `(*SpdyRoundTripper).NewConnection` | `lib/kube/proxy/roundtrip.go:207-221` | `(*http.Response)` | `(httpstream.Connection, error)` | On non-upgrade responses, reads the entire error body with `ioutil.ReadAll` to build the error message. |
| `(*Server).downloadRDSRootCert` | `lib/srv/db/aws.go:78-93` | `(string, string)` | `([]byte, error)` | GETs the CA URL and reads the full response body into memory before writing it to disk. |
| `(*Client).PostSessionSlice` | `lib/auth/clt.go:1611-1630` | `(events.SessionSlice)` | `error` | Sends a POST, then consumes the full response body with `ioutil.ReadAll` before converting it to an error. |

DATA FLOW ANALYSIS:
Variable: `data`
  - Created at: `lib/httplib/httplib.go:111`, `lib/auth/apiserver.go:1904`
  - Modified at: NEVER MODIFIED
  - Used at: `json.Unmarshal(...)` / `slice.Unmarshal(...)`
Variable: `bytes`
  - Created at: `lib/auth/github.go:665`, `lib/auth/oidc.go:730`, `lib/services/saml.go:57`, `lib/srv/db/aws.go:89`
  - Modified at: NEVER MODIFIED
  - Used at: JSON unmarshalling, error formatting, or file writes
Variable: `responseBytes`
  - Created at: `lib/auth/clt.go:1629`
  - Modified at: NEVER MODIFIED
  - Used at: `trace.ReadError(re.StatusCode, responseBytes)`

SEMANTIC PROPERTIES:
Property 1: Request-body reads are unbounded in the shared helper and at least one direct handler.
- Evidence: `lib/httplib/httplib.go:110-117`, `lib/auth/apiserver.go:1903-1910`
Property 2: Several response-body readers also buffer the full HTTP body before parsing or error handling.
- Evidence: `lib/auth/github.go:654-668`, `lib/auth/oidc.go:704-736`, `lib/services/saml.go:43-61`, `lib/kube/proxy/roundtrip.go:207-221`, `lib/srv/db/aws.go:78-93`, `lib/auth/clt.go:1611-1630`
Property 3: There is no shared `ReadAtMost` helper in the current tree, and no HTTP-path limit enforcement was found.
- Evidence: `rg -n "ReadAtMost" lib` returned no matches; `rg -n "MaxBytesReader|LimitReader" . --glob '!vendor/**'` found no relevant HTTP-body caps on these paths.

STEP 5 — ALTERNATIVE HYPOTHESIS CHECK

If the opposite answer were true, what evidence would exist?
- Searched for: a bounded-read helper or limit enforcement on these HTTP body paths (`ReadAtMost`, `io.LimitReader`, `http.MaxBytesReader`, or a `Content-Length` guard before `ReadAll`)
- Found: no `ReadAtMost` anywhere in `lib/`; no relevant `MaxBytesReader` usage; `ReadAll` is used directly in the cited request/response helpers
- Conclusion: REFUTED — the code does not currently cap these HTTP body reads.

STEP 6 — FORMAL CONCLUSION

By P1–P4 and the traced evidence:
- The root cause is that Teleport’s internal HTTP helpers read request and response bodies with `ioutil.ReadAll` directly, without any maximum-size guard.
- The shared request helper `httplib.ReadJSON` is especially important because many handlers call it, so the unbounded behavior propagates widely to user-facing endpoints.
- Several response-side helpers (`githubAPIClient.get`, `fetchGroupsPage`, `ValidateSAMLConnector`, `NewConnection`, `downloadRDSRootCert`, `PostSessionSlice`) also fully buffer upstream HTTP bodies before parsing or returning errors.
- Because there is no `ReadAtMost` helper or equivalent limit enforcement in these paths, a large or malicious body can force large allocations and memory pressure.

ANSWER: The issue is caused by unbounded `ioutil.ReadAll` usage on HTTP bodies throughout the codebase, especially in `httplib.ReadJSON` and several internal HTTP client/server helpers. The current implementation fully buffers entire request/response bodies into memory before validation, unmarshalling, or error formatting, so a sufficiently large body can exhaust memory and degrade performance.

CONFIDENCE: HIGH
