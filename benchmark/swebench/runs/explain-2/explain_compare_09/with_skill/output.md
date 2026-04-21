QUESTION: Why does importing a Trivy JSON report that contains only library findings stop with `Failed to fill CVEs. r.Release is empty`, and which code paths cause it?

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `parser.NewParser` | `contrib/trivy/parser/parser.go:22-33` | Chooses the Trivy parser implementation by schema version; schema `2` uses `v2.ParserV2`. | Entry point for `trivy-to-vuls` input. |
| `ParserV2.Parse` | `contrib/trivy/parser/v2/parser.go:20-35` | Unmarshals Trivy JSON into `types.Report`, calls `pkg.Convert(...)`, then `setScanResultMeta(...)`. | Main path for Trivy reports. |
| `setScanResultMeta` | `contrib/trivy/parser/v2/parser.go:40-74` | Sets `ServerName`; sets `Family` to pseudo by default; only sets `Family` and `Release` from `report.Metadata.OS` when OS metadata exists; marks the scan as Trivy. | Explains why library-only reports leave `Release` empty. |
| `pkg.Convert` | `contrib/trivy/pkg/converter.go:21-177` | Converts Trivy findings into `ScannedCves`, `Packages`, `SrcPackages`, and `LibraryScanners`; OS packages and library packages are handled in separate branches. | Shows library findings are processed, but no `Release` is populated here. |
| `Detect` | `detector/detector.go:34-55` | Runs `DetectLibsCves(...)` first, then `DetectPkgCves(...)`; any error aborts the whole scan pipeline. | Explains why a later package-detection failure stops output. |
| `DetectLibsCves` | `detector/library.go:42-90` | Scans `r.LibraryScanners`, updates `r.ScannedCves`, and never touches `Release`. | Confirms library CVEs are separate from OS metadata. |
| `isPkgCvesDetactable` | `detector/detector.go:259-267` in `fd18df1` | Historical behavior: if `r.Release == ""`, package-CVE detection is rejected immediately. Current HEAD logs and skips instead at `detector/detector.go:372-379`. | This is the release-empty gate behind the reported failure. |

DATA FLOW ANALYSIS:
- Variable: `scanResult.Release`
  - Created at: `contrib/trivy/parser/v2/parser.go:64-68` only when `report.Metadata.OS != nil`
  - Modified at: `NEVER` elsewhere in the Trivy parser path
  - Used at: `detector/detector.go:259-267` (historical gate) and `detector/detector.go:372-379` (current skip gate)
- Variable: `scanResult.LibraryScanners`
  - Created at: `contrib/trivy/pkg/converter.go:155-177`
  - Modified at: `detector/library.go:63-90`
  - Used at: `DetectLibsCves(...)` and nowhere to fill `Release`

SEMANTIC PROPERTIES:
Property 1: Library-only Trivy input does not imply OS metadata.
- Evidence: `setScanResultMeta` sets `Release` only when `report.Metadata.OS != nil` (`contrib/trivy/parser/v2/parser.go:64-68`).

Property 2: Library findings are still processed, but in a separate structure.
- Evidence: `pkg.Convert` stores them in `LibraryScanners` and `LibraryFixedIns`, not in `Release` (`contrib/trivy/pkg/converter.go:143-173`).

Property 3: The report pipeline does not stop after library scanning; it continues to package CVE detection.
- Evidence: `Detect()` calls `DetectLibsCves(...)` and then `DetectPkgCves(...)`, returning immediately on any error (`detector/detector.go:49-55`).

Property 4: The failure is caused by the empty-release gate, not by parsing the library CVEs themselves.
- Evidence: The historical gate checks `r.Release == ""` before package CVE detection (`fd18df1 detector/detector.go:259-267`).

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, there would be a path that fills `Release` from library-only Trivy data, or package-CVE detection would not depend on `Release`.
- Searched for: `Release` assignment in the Trivy conversion path and release-independent package detection.
- Found: `Release` is assigned only from `report.Metadata.OS.Name` in `setScanResultMeta` (`contrib/trivy/parser/v2/parser.go:64-68`); `DetectPkgCves` still checks the release gate (`detector/detector.go:259-267` historically, `372-379` current head).
- Conclusion: REFUTED.

FORMAL CONCLUSION:
By P2 and Property 1, a library-only Trivy report reaches `setScanResultMeta()` without OS metadata, so `scanResult.Release` stays empty. By P3 and Property 2, Trivy library findings are still converted and stored, but only in `LibraryScanners`/CVE structures, not in OS metadata. By P4 and Property 4, the scan then continues into `DetectPkgCves`, where the historical `isPkgCvesDetactable()` gate rejects empty `Release`; that is the code path behind the reported `Failed to fill CVEs. r.Release is empty` behavior. The current checkout has already softened that branch to a log-and-skip, but the responsible logic is the same empty-release check.

ANSWER: The behavior is caused by the Trivy parser leaving `Release` blank for reports with no `Metadata.OS`, followed by the package-detection gate that treats an empty `Release` as invalid. In the historical revision, that gate produced the reported failure; in current HEAD, it logs and skips instead.

CONFIDENCE: HIGH
