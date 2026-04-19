# Iteration 30 Discussion

## 検索
- 検索なし（理由: 提案の中心は「差分検出後に EQUIV / NOT_EQ の両方向へ同一トリガで短い探索を走らせる」という一般的な探索設計であり、既存研究の固有主張を追加導入するより、README.md / docs/design.md / SKILL.md / failed-approaches.md の範囲で自己完結に評価できるため）

## 総評
提案の核は、Compare checklist の既存 1 行
- "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
を、差分発見時に
- 反例成立側（diverging assertion へ届くか）
- 無害化側（test oracle が差分を吸収するか）
の二股探索へ置換する点にある。

これは「差分を見た後の次アクション」を変える提案であり、単なる説明強化ではなく compare の分岐規則に触れている。しかも 1 行置換・必須ゲート純増なしと明示しており、過度に保守的に拒否する理由は弱い。

## 1. 既存研究との整合性
- README.md / docs/design.md が強調する研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証。
- 本提案はそれらを削らず、compare における「必須反証」を差分検出直後の探索順序へ対称的に埋め込み直すもの。
- 特に docs/design.md の「per-item iteration as the anti-skip mechanism」「incomplete reasoning chains 防止」と整合的で、Guardrail #4 の具体化として自然。
- 研究コアを逸脱して新しい判定哲学を持ち込むものではなく、既存の semi-formal reasoning を compare の decision point に寄せて再配置した提案と見なせる。

## 2. Exploration Framework のカテゴリ選定
判定: A. 推論の順序・構造を変える で妥当。

理由:
- 変えているのは「何を根拠に結論するか」そのものではなく、「差分を見た直後にどちら向きの探索を先に/並列に短く走らせるか」という順序・構造。
- 証拠の種類を固定する提案ではなく、同一トリガで両方向の探索を対称化するものなので、B（取得方法）やE（表現）より A が中心。
- D（自己チェック強化）寄りにも見えるが、結論直前の監査追加ではなく、探索の途中分岐を変える点で A とみるのが適切。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側: 単に「差分あり」だけで NOT_EQ に倒れるのを防ぎ、test oracle の吸収・正規化・比較粒度によって実効差分が消えるケースを拾いやすくする。
- NOT_EQUIVALENT 側: 単に「影響なし」を正当化する追跡だけで終わるのを防ぎ、diverging assertion へ届く反例トレースを早めに探すことで、偽 EQUIV を減らしやすくする。
- 実効差分としては、変更前が「no impact の正当化」へ重心を置いていたのに対し、変更後は「反例成立 vs オラクル吸収」の識別的証拠を同一トリガで取りにいく。
- したがって片方向最適化ではなく、両方向の誤判定を同じ箇所で減らす設計になっている。

## 4. failed-approaches.md との照合
総論として、本質的再演の可能性は低い。ただし文言の運び方次第で「証拠種類の半固定」に寄るリスクはある。

- 「探索経路の半固定」: NO
  - 理由: 「差分を見たら二股化する」はトリガベースの分岐であり、読み始め順・確定順を半固定していない。
- 「必須ゲート増」: NO
  - 理由: proposal 自身が 1 行置換・必須ゲート純増なし・総量不変を明示している。
- 「証拠種類の事前固定」: NO（軽微懸念あり）
  - 理由: 反例 / 吸収 は証拠テンプレの固定というより結論候補の対称化。ただし実装文言が「必ず assertion と normalization を探せ」のように狭くなると再演化するので、最終文言は abstract に保つべき。

## 5. 汎化性チェック
判定: 概ね良好。

- 提案文に特定の数値 ID、ベンチマーク case ID、リポジトリ名、テスト名、実コード断片は見当たらない。
- 含まれる数値は「1行置換」「5行以内」等の変更規模表現であり、ベンチマーク識別子ではない。
- 例示は「丸め・ソート・例外型のみ確認」「内部表現・順序・メッセージ」など一般的で、特定言語や特定ドメインに閉じていない。
- ただし "counterexample-to-assertion" と "oracle-absorbs-diff" を最終実装で狭いテスト文化に寄せて書くと、assert 主体の単体テスト像に暗黙依存しやすい。discussion 段階では許容だが、実装では「diverging observable test check」程度に少し抽象化してもよい。

## 6. 期待される推論品質の向上
- 差分発見後の確認バイアスを減らせる。従来は「影響なし」側の追跡に流れやすかったが、同時に反例成立側も短く試すことで片寄りを抑えられる。
- compare における主要な誤りである「差分＝即 NOT_EQ」と「差分はあるが影響なしだろう＝即 EQUIV」の両方に対し、識別的な追加探索を要求できる。
- 変更点が局所的なので、研究コアや他モードへ波及せず、回帰リスクを比較的低く抑えながら compare の意思決定密度だけを上げられる。

## 停滞診断
- 懸念点（1点のみ）: proposal は比較的よくできているが、実装時に「split probe」の説明だけが増えて、実際には agent が従来通り EQUIV 側の no-impact justification を主に行うなら、監査 rubic には刺さっても compare の実行判断はあまり変わらない。

- failed-approaches 該当性
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - セマンティック差分を見つけたとき、回答生成前に「反例トレース」か「吸収証拠」かのどちらが先に見つかったかで、ANSWER と CONFIDENCE と追加探索要求が変わりうる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Before/After が条件も行動も同じで理由だけ言い換えか？ NO
  - Trigger line（発火する文言の自己引用）が差分プレビュー内に含まれているか？ YES
  - コメント: ここは具体で、compare に効く分岐になっている。

- 2) Failure-mode target:
  - 対象は両方。
  - 偽 EQUIV: semantic difference を見つけても露出 assert への到達確認が弱く、影響なしに倒してしまう。
  - 偽 NOT_EQ: semantic difference を見つけた時点で test oracle による吸収可能性を確かめず、差分ありをそのまま outcome 差とみなしてしまう。

- 3) Non-goal:
  - 読み始め順や証拠型を固定しない。
  - 構造差の早期 NOT_EQ 条件を観測境界へ狭めない。
  - 新しい結論前メタゲートを増やさない。

- Discriminative probe:
  - 抽象ケースとして、2変更が内部順序だけ異なるが、あるテストは集合比較で吸収し、別のテストは順序文字列を直接比較するとする。
  - 変更前は agent がどちらか片側だけを見て偽 EQUIV または偽 NOT_EQ に寄りやすい。変更後は同じ差分トリガで「露出する比較」と「吸収する比較」の両方を短く探すため、 test outcome 差の有無をより直接に識別できる。
  - これは新規ゲート追加ではなく、既存の no-impact tracing 1 行を split probe に置き換える説明で成立している。

- 支払い（必須ゲート総量不変）の明示:
  - YES。proposal は「Compare checklist の 1 行置換」「必須ゲート純増なし」を明記しており、A/B 対応は足りている。

## 最大の懸念
最大ブロッカーにはしないが、実装文言が具体化されすぎて「assert / normalization という特定証拠型を必ず探す」調子になると、failed-approaches の「証拠種類の事前固定」に近づく。このため、最終文言は test-oracle evidence を抽象的に書き、例示は任意扱いに留めるのが安全。

## 修正指示
1. split probe の 2 本目は "oracle-absorbs-diff" をそのまま固定語にせず、"evidence that the relevant test observation treats the difference as immaterial" のように少し抽象化すること。
2. After 行の action は「attempt both briefly, then choose based on discriminative evidence」とし、二股探索が新しい長大な必須工程に見えないよう短さを維持すること。
3. 現行 1 行との置換関係を diff preview でさらに明確にし、追加でなく置換であることを一目で分かる形に保つこと。

## 結論
この提案は、監査に通るための説明強化だけでなく、compare の分岐点を実際に変える具体性がある。failed-approaches の主要禁則にも正面からは抵触しておらず、しかも片方向最適化ではなく EQUIV / NOT_EQ の双方に効く。

承認: YES
