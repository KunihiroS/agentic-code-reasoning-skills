The root cause is that Teleport’s HTTP helpers eagerly buffer entire request/response bodies with `ioutil.ReadAll` and never apply a byte limit before doing so. There is no bounded-read utility in these paths (`ReadAtMost` does not exist in the codebase), so a large or malicious body is fully loaded into memory.

Verified examples:

- Request bodies:
  - `lib/httplib/httplib.go:110-118` — `ReadJSON` does `ioutil.ReadAll(r.Body)` and then `json.Unmarshal(...)`.
  - `lib/auth/apiserver.go:1902-1910` — `postSessionSlice` does `ioutil.ReadAll(r.Body)` before unmarshaling the session slice.
  - `lib/web/users.go:74-77` and `lib/web/apiserver.go:895-899` both call `httplib.ReadJSON`, so many handlers inherit the same unbounded read.

- Response bodies:
  - `lib/auth/github.go:653-678` — `githubAPIClient.get` reads the full `response.Body` with `ioutil.ReadAll`.
  - `lib/auth/oidc.go:724-740` — the GSuite/OIDC helper reads the full `resp.Body`.
  - `lib/services/saml.go:48-62` — `ValidateSAMLConnector` reads the full HTTP response body from the entity-descriptor URL.
  - `lib/srv/db/aws.go:78-98` — `downloadRDSRootCert` reads the full response body.
  - `lib/kube/proxy/roundtrip.go:205-224` — `NewConnection` reads the full error response body.

How this leads to the issue:
- These functions convert the whole body into a `[]byte` before any parsing or error handling.
- Because there is no size cap (`io.LimitReader`, `http.MaxBytesReader`, or a `ReadAtMost` helper), the amount of memory consumed is proportional to the size of the incoming HTTP body.
- That means an attacker can force large allocations simply by sending or causing a large HTTP request/response body, which is the resource-exhaustion/DoS risk described in the issue.
