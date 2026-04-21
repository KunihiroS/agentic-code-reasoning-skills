QUESTION: Why audio metadata lacks channel count, and what code path causes it?

STEP 1: Task and constraints  
- Static inspection only; no running code.  
- Need a traced explanation with `file:line` evidence.  
- Must verify where channel information is lost in the metadata pipeline.

STEP 2: Numbered premises  
P1: The reported bug is that extracted audio metadata includes duration/bit-rate but not channel count.  
P2: The scanner gets metadata through `scanner/metadata.Extract(...)` and then maps it into `model.MediaFile`.  
P3: The ffmpeg output sample used by tests contains a channel descriptor in the audio stream line, e.g. `stereo`.  
P4: The repository must expose channel count through the metadata API/model for the bug to be fixed.  
P5: I found no `Channels()` / `ChannelCount()` accessor or `channels` field in the metadata/model code.

HYPOTHESIS H1: The bug is caused by the ffmpeg parser extracting duration/bitrate but never parsing channel information from the audio stream line.  
EVIDENCE: P1, P2, P3.  
CONFIDENCE: high

OBSERVATIONS from `scanner/metadata/ffmpeg/ffmpeg.go`:
- O1: `Parser.Parse` shells out to the probe command, splits output by file, and passes each chunk to `extractMetadata` (`ffmpeg.go:20-38`).
- O2: `extractMetadata` delegates to `parseInfo`, then only adds alias tags for `disc` and `has_picture`; no channel-related tag is added (`ffmpeg.go:41-59`).
- O3: `parseInfo` recognizes tag lines, cover art, duration, and bitrate only. The only regex for the audio stream line is `bitRateRx`, which captures `(..., (\d+) kb/s)`; it does not capture the channel descriptor such as `stereo` or `mono` (`ffmpeg.go:62-157`).
- O4: The test fixtures explicitly show ffmpeg lines like `Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s` (`ffmpeg_test.go:48-50`, `83-89`, `105-110`, `187-194`).

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the ffmpeg parser reads the relevant line but only extracts bitrate, not channels.

OBSERVATIONS from `scanner/metadata/metadata.go`:
- O5: `Extract` selects the parser and wraps the returned tag map into `metadata.Tags` objects; it does not derive any extra audio properties itself (`metadata.go:30-58`).
- O6: `metadata.Tags` exposes `Duration()` and `BitRate()` for file properties, but there is no channel-count accessor in this type (`metadata.go:69-117`).
- O7: The helper methods normalize tags into values, but none handle channels (`metadata.go:119-156`).

HYPOTHESIS UPDATE:
- H1: REFINED — the loss happens both in parsing and in the public tag API: the parser never produces a channel tag, and `Tags` has no channel getter.

OBSERVATIONS from `scanner/tag_scanner.go`:
- O8: `TagScanner.loadTracks` calls `metadata.Extract(filePaths...)` and then converts each `metadata.Tags` into a `model.MediaFile` (`tag_scanner.go:373-384`).

HYPOTHESIS UPDATE:
- H1: REFINED — this confirms the production path from parser output to stored media metadata.

OBSERVATIONS from `scanner/mapping.go`:
- O9: `mediaFileMapper.toMediaFile` copies a fixed set of fields from `metadata.Tags` into `model.MediaFile`, including `Duration` and `BitRate`, but no channel-related field (`mapping.go:34-77`).

OBSERVATIONS from `model/mediafile.go`:
- O10: `model.MediaFile` has fields for duration and bitrate, but no channel-count field at all (`mediafile.go:8-52`).

OBSERVATIONS from `scanner/metadata/taglib/taglib.go`:
- O11: The taglib parser also only derives duration from `lengthinmilliseconds` and maps a small set of alias tags; it does not add any channel-count metadata either (`taglib.go:21-49`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `TagScanner.loadTracks` | `scanner/tag_scanner.go:373-384` | `([]string)` | `(model.MediaFiles, error)` | Calls `metadata.Extract`, then maps each `metadata.Tags` to `model.MediaFile`. |
| `metadata.Extract` | `scanner/metadata/metadata.go:30-58` | `(...string)` | `(map[string]Tags, error)` | Picks ffmpeg/taglib parser, wraps parsed tag maps into `Tags`, no extra derived audio properties. |
| `ffmpeg.Parser.Parse` | `scanner/metadata/ffmpeg/ffmpeg.go:20-38` | `(...string)` | `(map[string]parsedTags, error)` | Runs probe command, splits output per file, delegates each chunk to `extractMetadata`. |
| `ffmpeg.Parser.extractMetadata` | `scanner/metadata/ffmpeg/ffmpeg.go:41-59` | `(string, string)` | `(parsedTags, error)` | Calls `parseInfo`; only adds `disc` and `has_picture` aliases, nothing for channels. |
| `ffmpeg.Parser.parseInfo` | `scanner/metadata/ffmpeg/ffmpeg.go:104-165` | `(string)` | `map[string][]string` | Parses tag lines, cover art, duration, bitrate; does not parse channel descriptors from audio stream lines. |
| `metadata.Tags.Duration` | `scanner/metadata/metadata.go:112-113` | `()` | `float32` | Returns parsed `duration` tag as float. |
| `metadata.Tags.BitRate` | `scanner/metadata/metadata.go:112-113` | `()` | `int` | Returns parsed `bitrate` tag as int. |
| `mediaFileMapper.toMediaFile` | `scanner/mapping.go:34-77` | `(metadata.Tags)` | `model.MediaFile` | Copies duration/bitrate and other tags into DB model, but no channel field. |
| `taglib.Parser.extractMetadata` | `scanner/metadata/taglib/taglib.go:21-49` | `(string)` | `parsedTags` | Derives duration and alias tags only; no channel-count handling. |

DATA FLOW ANALYSIS:
Variable: `info`  
- Created at: `scanner/metadata/ffmpeg/ffmpeg.go:89-99` in `parseOutput`  
- Modified at: never modified after assignment  
- Used at: passed into `extractMetadata` (`ffmpeg.go:31-32`), then into `parseInfo` (`ffmpeg.go:42`)

Variable: `tags`  
- Created at: `scanner/metadata/ffmpeg/ffmpeg.go:105` in `parseInfo`  
- Modified at: tag-line parsing (`ffmpeg.go:115-123`), continuation handling (`126-135`), cover art (`139-142`), duration/bitrate (`145-157`), and alias expansion in `extractMetadata` (`41-59`)  
- Used at: returned from parser, wrapped by `metadata.Extract` (`metadata.go:43-55`), then converted by `toMediaFile` (`mapping.go:34-77`)

Variable: `mf`  
- Created at: `scanner/mapping.go:35`  
- Modified at: duration/bitrate and many other fields (`mapping.go:36-75`)  
- Used at: returned as `model.MediaFile` (`mapping.go:77`)

SEMANTIC PROPERTIES:
Property 1: The ffmpeg parser does not interpret the audio stream’s channel descriptor.  
- Evidence: `ffmpeg.go:75-76` defines only `bitRateRx` for `Audio: ..., (\d+) kb/s`; `ffmpeg.go:145-157` stores duration/bitrate only. The test input contains `stereo` on that line (`ffmpeg_test.go:48-50`, `83-89`).

Property 2: The public metadata wrapper exposes duration/bitrate but no channel-count API.  
- Evidence: `metadata.go:69-117` includes `Duration()` and `BitRate()`, but no channel getter or field.

Property 3: The scanner mapping layer cannot persist channel count because the model has no slot for it.  
- Evidence: `mapping.go:34-77` copies many fields but none for channels; `mediafile.go:8-52` contains no channel-count field.

Property 4: Taglib is not a workaround for this bug.  
- Evidence: `taglib.go:21-49` only derives duration and existing aliases; no channel data is added.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, what evidence would exist?
- Searched for: `Channels`, `ChannelCount`, `channel_count`, `channels` across `repo_nav`, plus a parser regex or model field for channel count.
- Found: no matching metadata/model API definitions; the inspected parser/model code only contains duration/bitrate handling (`metadata.go:69-117`, `ffmpeg.go:104-157`, `mapping.go:34-77`, `mediafile.go:8-52`).
- Conclusion: REFUTED — there is no implemented path that could preserve and expose channel count.

FINAL ANSWER:
The bug occurs because the metadata pipeline never turns ffmpeg’s channel description into a stored field.

Concrete path:
1. `TagScanner.loadTracks` calls `metadata.Extract` (`tag_scanner.go:373-384`).
2. `metadata.Extract` selects the configured parser and wraps its tag map into `metadata.Tags` (`metadata.go:30-58`).
3. With the ffmpeg extractor, `parseInfo` reads the stream output. It recognizes tags, cover art, duration, and bitrate, but the audio-stream regex only captures the bitrate portion of lines like `Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s`; the `stereo` part is ignored (`ffmpeg.go:62-157`, `ffmpeg_test.go:48-50`, `83-89`).
4. `metadata.Tags` exposes `Duration()` and `BitRate()`, but no channel accessor exists (`metadata.go:69-117`).
5. `mediaFileMapper.toMediaFile` copies duration/bitrate and other fields into `model.MediaFile`, but not channels (`mapping.go:34-77`).
6. `model.MediaFile` itself has no channel-count field to receive such data (`mediafile.go:8-52`).

So the omission is not a single bug at one place; it is an end-to-end gap:
- parser does not parse channels,
- metadata API does not expose channels,
- media model does not store channels.

By P1–P5 and O1–O11, the result is exactly what you observed: duration and bitrate are present, but channel count is never produced or persisted.

CONFIDENCE: HIGH
