The bug happens because the metadata pipeline never carries channel information from the probe output into the stored/exposed media model.

### 1) The ffmpeg parser only extracts duration, bitrate, and cover-art — not channels
In `scanner/metadata/ffmpeg/ffmpeg.go`, `parseInfo()` recognizes:
- arbitrary key/value metadata tags,
- cover-art lines,
- the `Duration: ... bitrate: ...` header,
- and audio-stream bitrate.

But there is no branch or regex that captures the channel description from lines like:

`Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s`

Relevant code:
- `durationRx` / `bitRateRx` are the only audio-property regexes: `ffmpeg.go:72-77`
- `parseInfo()` stores only `duration` and `bitrate`, never a channel count: `ffmpeg.go:145-157`

So the `stereo` token is ignored by the parser.

### 2) The TagLib extractor also does not export channel count
If the system uses the default extractor, it goes through TagLib instead of ffmpeg:

- default extractor is `taglib`: `consts/consts.go:52`
- `metadata.Extract()` selects the configured parser: `scanner/metadata/metadata.go:30-38`
- the TagLib wrapper only writes `duration`, `lengthinmilliseconds`, `bitrate`, and tags into the map: `scanner/metadata/taglib/taglib_wrapper.cpp:25-30`

There is no channel-count field coming out of TagLib either.

### 3) The metadata API has no channel accessor
Even after extraction, `metadata.Tags` only exposes:
- `Duration()` and `BitRate()`: `scanner/metadata/metadata.go:110-117`

There is no `Channels()` method, so nothing in the metadata API can query channel count.

### 4) The scanner maps only the supported fields into `MediaFile`
`TagScanner.loadTracks()` gets `Tags` from `metadata.Extract()` and converts them into `model.MediaFile` objects: `scanner/tag_scanner.go:373-384`

The mapper copies duration and bitrate, but not channels:
- `mediaFileMapper.toMediaFile()`: `scanner/mapping.go:34-77`
- specifically `mf.Duration = md.Duration()` and `mf.BitRate = md.BitRate()` at `mapping.go:51-52`

### 5) The stored media model and API responses have no channel field
`model.MediaFile` defines fields like `Duration` and `BitRate`, but no `Channels`: `model/mediafile.go:8-53`

That means:
- there is no DB-backed field to persist channel count,
- the native API registers `model.MediaFile` directly for `/song`: `server/nativeapi/native_api.go:31-37`
- the Subsonic response mapping copies only the fields present in `model.MediaFile` into `responses.Child`, which also has no `Channels` field: `server/subsonic/helpers.go:134-170` and `server/subsonic/responses/responses.go:96-125`

### Bottom line
The bug occurs because the code path stops at bitrate/duration extraction:
1. probe output contains a channel descriptor (`mono`, `stereo`, etc.),
2. the ffmpeg parser ignores it, and TagLib never exports it,
3. `metadata.Tags` has no channel accessor,
4. `mediaFileMapper` does not map any channel count,
5. `model.MediaFile` / DB schema / API responses have no channel field.

So even though the decoder output includes “stereo”, the value is lost before it can be stored or returned by any metadata API.
