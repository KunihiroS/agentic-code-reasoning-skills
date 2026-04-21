# Iteration 1 Discussion

## 監査コメント

### 1. 既存研究との整合性
- 検索なし（理由: 本提案は「relevant test の探索順序を、直接 identifier hit 依存から call-path 上の共有結節点探索へ広げる」という一般的な探索戦略の話であり、README.md / docs/design.md / SKILL.md の範囲で自己完結に評価できる）
- 研究コアとの整合性は概ね良い。提案は結論ラベルの直指定ではなく、D2 の relevant test 発見手順を改善するもので、番号付き前提・仮説駆動探索・手続き間トレース・反証を削っていない。
- 特に docs/design.md の「per-item iteration as the anti-skip mechanism」とは整合する。pass-to-pass 側で relevant tests の拾い漏れを減らす方向だから、per-test tracing の入力集合を改善する提案として理解できる。

### 2. Exploration Framework のカテゴリ選定
- カテゴリ B「情報の取得方法を改善する」は適切。
- 提案の実体は、何を結論するかではなく「relevant tests をどう見つけるか」「探索の優先順位をどう切り替えるか」の変更だから、A や C より B が最も自然。
- ただし payment で STRUCTURAL TRIAGE を demote/remove しているため、B 単独というより「B を主、A に軽く接触」という性質はある。ここが副作用評価の中心になる。

### 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側: 直接参照が薄い変更でも outward search により candidate relevant tests が増えうるので、過少探索のまま premature EQUIV に倒れる偽 EQUIV を減らす効果は期待できる。
- NOT_EQUIVALENT 側: 間接経路の relevant tests を拾えるようになれば、本当に差が出る assertion へ到達しやすくなる点はプラス。
- ただし proposal は payment として「Structural triage first」を demote/remove しており、従来の早期 NOT_EQUIV 側の安全装置を外す一方、その代替として `impact witness` を要求していない。結果として、EQUIV 側の取りこぼし補正には効いても、NOT_EQUIV 側で何をもって早期に差ありとするかの分岐が弱くなり、片方向最適化の懸念が残る。
- よって「両方向に作用しうる」こと自体は示せているが、逆方向悪化を防ぐ回避策が不足している。

### 4. failed-approaches.md との照合
- failed-approaches.md 自体には現時点で具体ブラックリストは未記載。
- ただし運用上の汎用失敗原則との照合では以下の通り。
  - 探索経路の半固定: NO（`if direct hit is sparse/absent` という条件付きで発火しており、常時固定ルートではない）
  - 必須ゲート増: NO（proposal 上は payment が明示され、必須ゲート総量不変を意識している）
  - 証拠種類の事前固定: NO寄り。ただし `shared control point (exported wrapper, dispatch table, registration, config key, or exception translation site)` の列挙が実装時に閉じたチェックリストとして読まれると危ない。例示であって exhaustiveness ではない旨は補強した方がよい。
- 本質的な再演とは言いにくいが、STRUCTURAL TRIAGE を外す側の修正なので、停滞ではなく回帰を生まないための補助条件が必要。

### 5. 汎化性チェック
- 明示的な固有識別子違反は見当たらない。具体的な数値 ID、ベンチマークのケース ID、特定リポジトリ名、特定テスト名、実コード断片は含まれていない。
- `wrapper / dispatch table / registration / config key / exception translation` は一般概念の例示として許容範囲。
- ただし暗黙には「参照探索可能な call-path / control-point が存在する典型的アプリ構造」を想定している。十分に汎用ではあるが、動的ディスパッチが強い言語や宣言的構成が中心の環境では control point の見つけ方が曖昧になりうる。

### 6. 全体の推論品質の改善期待
- 改善余地の本丸は明確。現行 D2 の「changed symbol への test 参照検索」だけでは間接経路の pass-to-pass tests を漏らしやすく、そこが compare の精度劣化点になる、という問題設定は妥当。
- 提案はそのボトルネックに直接当たっているため、relevant test の想起精度は上がりうる。
- ただし compare の実行時アウトカム差を安定化するには、「outward search で見つけた candidate が本当に outcome に効くか」を確認する witness 条件まで必要。そこが抜けると、監査説明としては強いが compare の意思決定差が不均一になる。

## 停滞診断
- 懸念点: 提案は「sparse/absent direct hit のとき outward search する」という監査受けの良い説明を持っている一方、compare 実行で最終的に「追加探索する」「結論保留する」「NOT_EQUIV に倒す」をどう切り替えるかの witness 条件が弱く、説明強化に比べて意思決定差の定義が薄い。
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - direct reference hit が sparse/absent なケースで、compare はそのまま tracing を始めず、shared control point 探索を追加要求するようになる。
  - その結果、premature EQUIV を出す条件は厳しくなる一方、現 proposal だけでは NOT_EQUIV を早期に出す条件の置換先が弱い。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES
  - 評価: 条件と行動の両方が変わっており、単なる理由の言い換えではない点は良い。

- 2) Failure-mode target:
  - 主標的は偽 EQUIV。メカニズムは、indirect path 上の pass-to-pass tests を relevant set に昇格できず、観測すべき差を未探索のまま EQUIV としてしまう失敗を減らすこと。
  - 副次的には真の NOT_EQUIV の取りこぼしも減らせる。
  - ただし outward search の候補拡張だけでは、偽 NOT_EQUIV を抑える制御は増えない。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ YES
  - NOT_EQUIV の根拠が「ファイル差がある」だけに退化していないか: 現 proposal はそこを強化するのではなく、むしろ既存 triage を demote/remove する方向。
  - `impact witness`（PASS/FAIL に結びつく具体的な assertion boundary を 1 つ目撃する要求）を提案が要求しているか？ NO
  - 評価: ここが最大の弱点。STRUCTURAL TRIAGE を触るなら、早期 NOT_EQUIV を弱めた後の置換先として「shared control point から少なくとも 1 つの assertion boundary まで tracing して relevance を確定する」程度の witness が必要。

- 3) Non-goal:
  - 常に outward search を必須化しないこと。
  - shared control point の例示を閉じた証拠種別リストにしないこと。
  - 既存の per-test tracing / refutation を置き換えず、relevant test discovery の入口だけを差し替えること。

- 追加チェック: Discriminative probe
  - 提案文の probe 自体はある程度よくできている。helper 名に direct hit がなく public wrapper 経由でのみ既存 test が踏む抽象ケースは、変更前に偽 EQUIV を生みやすく、変更後に避けられる筋が見える。
  - ただし probe は「candidate relevant tests に昇格する」までで止まっており、その candidate が実際に assertion boundary を変えるかの witness まで結んでいない。ここが compare 実効差の最後の一歩として不足。

- 追加チェック（停滞対策の検証）:
  - 支払い（必須ゲート総量不変）の A/B 対応付けが proposal 内で明示されているか: YES
  - その点は良い。ただし支払い先に選んだのが STRUCTURAL TRIAGE なので、副作用を相殺する置換条件が必要。

## 総合判断
- 良い点は明確で、B カテゴリとして筋も良い。direct identifier hit 依存の relevant test 発見を緩める発想は compare の弱点に直接効く。
- しかし現案は、EQUIV 側の取りこぼし補正に比重が寄り、payment として STRUCTURAL TRIAGE を demote/remove するのに、その代わりとなる `impact witness` を置いていない。これは reverse side、特に NOT_EQUIVALENT 側の分岐条件を弱めるので、片方向最適化の懸念が解消していない。

## 修正指示（2〜3点）
1. `Structural triage first` を丸ごと demote/remove するのではなく、早期結論部分だけを弱め、置換として「shared control point から少なくとも 1 つの assertion boundary まで tracing して relevance を確定する」必須 1 行を入れてください。追加するなら、既存 triage の早期直行文を optional 化する形で支払ってください。
2. `shared control point` の列挙は exhaustive な証拠種別に見えないよう、`for example` 相当の但し書きを入れてください。証拠種類の事前固定に読まれるリスクを避けられます。
3. Decision-point delta の After 側に、「control point を見つけた後、どの条件で追加探索を止めて relevance を確定するか」を 1 行だけ足してください。理由説明ではなく、分岐条件として書いてください。

承認: NO（理由: focus_domain の片方向最適化で逆方向の悪化が明白で、STRUCTURAL TRIAGE を触るのに impact witness がない）
