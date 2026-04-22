# Iteration 40 — proposal 監査コメント

## 概要判断
提案は compare の実行時分岐を実際に変える形で書けており、Decision-point delta / Trigger line / Payment / Discriminative probe も明示されている点は良いです。特に「差分を見つけた後、すぐ SAME に寄る/曖昧に confidence へ逃がす」問題を局所的に是正したい、という狙い自体は妥当です。

ただし、提案の中核である「earliest divergence と first downstream absorber/preserver を 1 組で必須化してから Comparison: SAME を書かせる」は、failed-approaches.md 原則1の禁止方向とかなり近く、本質的再演に見えます。ここが最大ブロッカーです。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。
README.md / docs/design.md だけで、compare に未導入の localize 側 divergence analysis を移植する、という提案意図は十分追えます。研究コア（premises, hypothesis-driven exploration, interprocedural tracing, mandatory refutation）も維持されています。

## 2. Exploration Framework のカテゴリ選定
判定: 概ね適切

- 主分類を F「原論文の未活用アイデアを導入する」に置くのは自然です。docs/design.md にある localize の 4-phase pipeline のうち divergence analysis を compare に移す提案だからです。
- ただし実質的には G「認知負荷の削減（置換）」も混ざっています。edge-case 節を divergence-analysis 節に置換する payment があるためです。
- つまりカテゴリ F 単独でも不自然ではないが、実装メカニズムは F+G の複合です。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 中間差分を見つけただけでは Comparison: SAME を即記入しにくくなる。
  - absorber/preserver が書けなければ、追加探索 or NOT YET VERIFIED 側へ分岐しうる。
  - EQUIV を出すときの根拠が「差分なし」ではなく「差分はあるが下流で吸収」を要求する形に変わる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれるか？ YES
  - 内容は理由言い換えではなく、SAME を書く条件を変えているので compare 影響は実在します。

- 2) Failure-mode target:
  - 対象: 両方
  - 偽 EQUIV: 中間差分を過小評価して SAME に寄る誤りを減らしたい。
  - 偽 NOT_EQUIV/過度保留: 差分の存在だけで重大視する代わりに、下流吸収の有無を追わせたい。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO
  - impact witness 要求の有無: N/A（本提案は structural triage の早期 NOT_EQUIV 条件を直接いじっていない）

- 3) Non-goal:
  - structural gap からの早期 NOT_EQUIV 条件には触れない。
  - 新モード追加はしない。
  - MUST 総量は payment で相殺し、edge-case 節を置換対象にしている。

- Discriminative probe:
  - 抽象ケースは十分に識別的です。途中の値/例外差が下流 handler で吸収されるか未確定な場面を置いており、変更前は「差分は小さい」で偽 EQUIV、または「まだ assertion まで見えていない」で保留しがち、変更後は absorber/preserver の追跡で分岐が変わる、と説明できています。
  - 追加の必須ゲート増設ではなく edge-case 節との置換として書けている点も条件を満たしています。

- 追加チェック（停滞対策の検証）:
  - 「支払い（必須ゲート総量不変）」の A/B 対応付けは明示されているか？ YES
  - `DIVERGENCE ANALYSIS` 追加 ↔ `EDGE CASES RELEVANT TO EXISTING TESTS` demote/remove の対応が proposal 内に明記されています。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT への作用:
  - いまより厳しくなります。差分を見つけた場合、単に「assertion まで違いが見えない」だけでは足りず、吸収点の提示が必要になるためです。
  - これは偽 EQUIV を減らす方向には効きますが、EQUIV を出すための証拠様式を特定の形に寄せます。

- NOT_EQUIVALENT への作用:
  - 直接「NOT_EQUIV にしやすくする」規則ではありません。むしろ absorber が見つからないと追加探索/NOT YET VERIFIED に寄りやすく、差分の存在だけで即 NOT_EQUIV にはしにくくなります。
  - よって片方向最適化ではなく、主として EQUIV 判定条件を締める変更です。ただし副作用として、EQUIV の前提証拠が重くなり、保留増を通じて相対的に NOT_EQUIV 側が増える可能性はあります。

結論として、名目上は「両方」だが、実効差の中心は EQUIVALENT 側の判定条件変更です。NOT_EQUIVALENT 側の改善は間接的です。

## 5. failed-approaches.md との照合
判定: 本質的再演の懸念が強い

- 原則1との近さが大きいです。failed-approaches.md には以下が明記されています。
  - 「特に EQUIVALENT 側で『最初の差分』と『それを吸収する後段処理』の対提示を既定化すると…」
- 今回の Trigger line はまさに
  - 「earliest divergence」
  - 「first downstream point that either absorbs or preserves it」
  の対提示を、Comparison: SAME の前提として既定化しています。
- つまり提案者は「局所場面だけ」「edge-case 置換」「構造差ルールには触れない」と限定していますが、失敗原則が警戒しているコア機構そのものは残っています。
- 原則3の「証拠種類の事前固定」にもやや接近しています。差分が見えた際の有効証拠を earliest divergence + first absorber/preserver という型に寄せるためです。

## 6. 汎化性チェック
判定: ルール違反なし

- 提案文中に具体的なベンチマーク ID、特定リポジトリ名、テスト名、実コード断片はありません。
- `C[N].1`, `C[N].2`, `file:line`, `branch/value/exception difference` は SKILL.md 内部テンプレートの自己参照/抽象記法であり、固有識別子ではありません。
- ただし暗黙の想定として、「途中差分 → 下流吸収/維持」という語彙は例外処理・正規化・ガード句が豊富なコードで特に自然で、単純なデータ変換や declarative 設定比較にはやや寄る可能性があります。致命的ではないですが、汎用表現にするなら absorber/preserver を唯一の語彙にしない方が安全です。

## 7. 全体の推論品質への期待効果
期待できる点:
- 「差分を見つけたあと雑に SAME と書く」雑な収束を減らす。
- incomplete chain を具体的な下流追跡に変換しやすい。
- edge-case の一般論列挙より、実際の判定分岐に近い観測を優先できる。

ただし懸念点:
- EQUIV 側の正当化様式を「再収束の説明」に寄せすぎると、差分そのものの識別力よりも吸収ストーリー構築が先行しやすい。
- その場合、compare は鋭くなるより「再収束を説明できるかどうか」のゲームに変質し、failed-approaches.md 原則1の失敗を再演します。

## 停滞診断（必須）
- 懸念 1 点:
  - あります。proposal は監査 rubric には刺さりやすい一方、compare の本質を「差分を見たら absorber/preserver を書く」に寄せており、意思決定そのものより“監査受けのよい証拠様式”を増やしている面があります。

- 「探索経路の半固定」該当: NO
- 「必須ゲート増」該当: NO
  - payment があり、総量不変の意図は明示されています。
- 「証拠種類の事前固定」該当: YES
  - 原因文言: `name that earliest divergence and trace to the first downstream point that either absorbs or preserves it`

## 最小修正指示
1. 最大修正点: `absorbs or preserves` を SAME 判定の既定要件にしないこと。
   - 削る/置換する対象は proposal の Trigger line です。
   - 代わりに「中間差分を見つけた場合、その差分が assertion outcome に到達するかを最短の実証経路で 1 本追う。吸収/維持は例であって必須ラベルではない」とし、証拠型の固定を弱めてください。

2. edge-case 節の完全置換ではなく、既存 Guardrail #4/#5 と ANALYSIS OF TEST BEHAVIOR の接続を短く補強する形へ寄せてください。
   - つまり新セクション名を立てるより、「差分を見たら少なくとも 1 本、assertion outcome までの影響経路を追う」と既存文脈に埋め込む方が failed-approaches の再演を避けやすいです。

3. NOT_EQUIVALENT 側への実効差を 1 行だけ具体化してください。
   - 例: absorber 不在それ自体を根拠にせず、`diverging assertion` か `impact witness` が観測できたときだけ DIFFERENT に進む、と明記する。
   - これも追加ではなく、現在の After 文の後半を置換して総量不変で入れるのがよいです。

## 最終判定
承認: NO（理由: failed-approaches.md 原則1の「最初の差分＋後段吸収の対提示を EQUIVALENT 側で既定化する」失敗の本質的再演に近い）
