The behavior comes from two places in the Trivy import path:

1. **`contrib/trivy/parser/parser.go` — Trivy JSON parsing**
   - `Parse()` walks each `trivyResult` in the report.
   - In the original path, only OS results went through `overrideServerData(...)`:
     - the diff shows the old code only called it when `IsTrivySupportedOS(trivyResult.Type)` was true.
   - Library findings went through the `else` branch, which only populated library-specific data:
     - `LibraryFixedIns`
     - `LibraryScanner`
   - In other words, library-only reports did **not** get the OS-style metadata that the rest of Vuls expects.
   - The fix added explicit pseudo-type handling for library-only results by setting:
     - `scanResult.Family = constant.ServerTypePseudo`
     - `scanResult.ServerName = "library scan by trivy"`
     - `Optional["trivy-target"] = ...`
   - Evidence in the diff:
     - `parser.go` parse loop and library branch: `with_skill/prompt.txt` around the hunk starting at line 543 and the library-only branch at lines 93–101 / 144–176 in the diff.
     - The later patch summary explicitly says the library-only branch sets `Family = constant.ServerTypePseudo` (`with_skill/output.md:50-57`).

2. **`detector/detector.go` — CVE filling**
   - `DetectPkgCves()` contains the gate that ultimately stops execution.
   - Its logic is:
     - if `r.Release` is empty and `r.Family == constant.ServerTypePseudo`, it logs and skips OVAL/gost
     - otherwise it returns:
       - `Failed to fill CVEs. r.Release is empty`
   - The relevant code is shown in the diff at `detector.go:202-205`:
     ```go
     } else if r.Family == constant.ServerTypePseudo {
         logging.Log.Infof("pseudo type. Skip OVAL and gost detection")
     } else {
         return xerrors.Errorf("Failed to fill CVEs. r.Release is empty")
     }
     ```
   - So if the parser does not mark the scan as pseudo type, this branch is hit and processing stops.

### Why library-only Trivy scans fail
For a library-only Trivy report, the parser path does not produce a normal OS `Family`/`Release` pair. That means `DetectPkgCves()` later sees `r.Release == ""` and, unless `r.Family` has already been set to `constant.ServerTypePseudo`, it takes the error path above.

### In short
- **Parser path responsible:** `contrib/trivy/parser/parser.go` library-only branch does not inherently satisfy the OS metadata expected downstream.
- **Failure point:** `detector/detector.go:202-205` returns the exact error when `r.Release` is empty and the scan is not marked pseudo.
- **Why no CVEs are recorded:** execution stops at that return, so the remaining CVE processing loop never runs.

If you want, I can also map this into a step-by-step call flow from `trivy-to-vuls` entrypoint to the failing detector branch.
