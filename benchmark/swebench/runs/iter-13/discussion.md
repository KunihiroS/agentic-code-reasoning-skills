# Iteration 13 Discussion

## 総評
提案の狙い自体は理解できる。`Step 5.5` の「NO があれば Step 6 前に fix」が、compare 実行時に過剰な再探索や保留を誘発しうる、という問題設定は妥当で、認知負荷削減カテゴリ G を選んだことも筋がよい。

ただし今回は、削る対象の切り方が広すぎる。`Step 5.5` には「証明書完備性のための重複」だけでなく、`EQUIVALENT` を出すときの最終的な証拠健全性を守る文言まで入っている。そこを節ごと削除し、しかも `counterexample search is inconclusive` まで Step 6 で吸収可能にすると、compare の停滞は減っても、`EQUIVALENT` 側の誤判定を増やす方向の片側最適化になりうる。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md / SKILL.md の研究コアは一貫して「certificate-based reasoning」「anti-skip のための per-item iteration」「mandatory refutation」にある。今回の提案はそのうち refutation 自体は残しているので完全逸脱ではないが、結論直前の証拠健全性チェックを節ごと落とすため、研究コアの“証明書としての締め”をやや弱める懸念がある。

## 2. Exploration Framework のカテゴリ選定
カテゴリ G（認知負荷の削減）は適切。
理由:
- 主張の中心が「重複 self-check の削除」「結論直前ゲートの圧縮」にある
- 新しい探索経路や新ラベル導入ではなく、既存の重複箇所の整理を狙っている
- Objective.md の G の説明「重複する指示や冗長な説明を統合・圧縮する」に合致する

ただし、G として成立するためには「重複だけを削る」必要がある。現状案は重複以外の安全柵まで同時に落としている点が問題。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
提案の主作用は「追加探索や保留を減らして Step 6 まで到達しやすくする」こと。これは主に以下へ効く。
- 改善見込み: 偽 NOT_EQUIV、または過度な保留
- 悪化リスク: 偽 EQUIV

理由:
- 変更前は、`UNVERIFIED` や refutation 不十分が残ると Step 5.5 により再探索へ戻されやすい
- 変更後は、それらを scoped conclusion + confidence 低下で吸収できる
- とくに proposal の追加文は `any counterexample search is inconclusive` まで吸収対象に含めているため、`EQUIVALENT` を支える「反例探索の不在確認」が弱いまま結論できてしまう

したがって、片方向にしか作用しないわけではないが、実効上は「停滞削減」方向に強く寄り、逆方向の悪化回避が不足している。

## 4. failed-approaches.md との照合
本質的再演ではない。
- 「探索経路の半固定」: NO
- 「必須ゲート増」: NO
- 「証拠種類の事前固定」: NO

補足:
- failed-approaches 原則 2 は「未確定性を広い既定動作として保留側へ倒しすぎない」なので、提案の問題意識自体はむしろ整合的
- 一方で、原則 2 の反対側へ振れすぎて「未確定性を広く結論へ吸収する」方向になっており、これは blacklist の再演ではないが、別種の片側最適化リスクがある

## 5. 汎化性チェック
汎化性は概ね良好。
- 具体的な数値 ID、対象リポジトリ名、テスト名、実コード断片は含まれていない
- 引用は SKILL.md 自身の文言であり、Objective.md の R1 でも許容範囲
- 特定言語・特定フレームワーク依存の文言もない

軽微な所見:
- `haiku 系モデル` への言及は、特定ベンチマーク対象ではないが、モデル特性依存の説明にやや寄っている。ルール違反ではないが、理屈はモデル名なしでも成立するので、最終実装理由では一般化してよい

## 6. 全体の推論品質への期待効果
期待できる改善:
- 重複チェックによる認知負荷の軽減
- 結論直前の無駄な再探索の抑制
- `UNVERIFIED` を明示した scoped conclusion を出しやすくする点

ただし今回の文面のままだと、改善されるのは主に「結論を出す速さ・到達率」であって、「compare の識別精度」ではない可能性がある。特に `EQUIVALENT` のときは、反例探索が inconclusive でも結論へ進めるように読めるため、推論品質を上げるというより、判定閾値を緩めるだけになりやすい。

## 停滞診断（必須）
懸念点 1 点:
- 提案は audit rubric 上は「重複削減」「payment 明示」「Trigger line あり」で通りやすいが、compare の実質的な改善が「再探索しないで結論に進む」に偏っており、判定境界そのものをどこまで改善するかが弱い。とくに `counterexample search is inconclusive` を吸収する部分は、説明強化に対して判定品質の裏付けが薄い。

failed-approaches 該当性:
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - 観測可能な差はある。`Step 5.5` 由来の再探索が減り、以前なら保留/追加探索に倒れていたケースで、`UNVERIFIED` 明示つきの `ANSWER` と `LOW/MEDIUM CONFIDENCE` が出やすくなる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES
  - 所見: 形式要件は満たす。ただし実質は「証明書完備性を要求するか否か」の変更であり、`EQUIVALENT` のときに必要な反例不在確認まで弱めるため、分岐改善というより判定閾値緩和に近い。

- 2) Failure-mode target:
  - 主ターゲット: 偽 NOT_EQUIV / 過度な保留
  - メカニズム: `UNVERIFIED` や未解決事項を再探索トリガではなく scoped conclusion に吸収する
  - ただし副作用として、偽 EQUIV が増えうる。理由は `counterexample search is inconclusive` を EQUIV 側でも吸収可能にしているため

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  - NO

- 3) Non-goal:
  - 新しい探索経路の固定化、必須ゲートの増設、証拠種類の事前固定はしない、という境界は明示されている
  - ただし「何を削る代わりに何を残すか」の境界が粗く、Step 5.5 内の非重複な安全柵まで一緒に落としている

追加チェック:
- Discriminative probe:
  - 抽象ケース自体はある程度具体で、変更前は保留に寄り、変更後は `EQUIV + lower confidence` に進む差を示せている
  - ただしそのケースは「source unavailable helper が残る」場面であり、`no counterexample exists` の成立条件までは切り分けていない。ゆえに compare 誤判定回避の説明としては半分足りず、`EQUIVALENT` 側の安全性を示せていない

追加チェック（停滞対策の検証）:
- 「支払い（必須ゲート総量不変）」の A/B 対応付けが明示されているか: YES
- ただし支払い対象が不適切。削除側は `certificate completeness` だけでなく `trace-to-file:line` と `actual refutation evidence` の最終確認まで含むため、1 行の追加では価値対等になっていない

## 結論
最大のブロッカーは 1 つ:
- `counterexample search is inconclusive` を scoped conclusion に吸収してよい、としている点。これは compare の停滞を減らす一方、`EQUIVALENT` 判定の根拠を片側で弱め、偽 EQUIV を増やしうる。つまり focus_domain の片方向最適化で、逆方向の悪化回避策が不足している。

## 修正指示（2〜3点）
1. 削除対象を `Step 5.5` 節全体ではなく、「NO なら fix it before Step 6」という再探索強制の 1 行に限定してください。
   - 支払いとして、残すべき `trace to file:line` / `UNVERIFIED explicitly stated` / `actual refutation evidence` の最終確認は維持する
   - つまり「節削除」ではなく「強制再探索ゲートのみ optional 化/言い換え」に寄せる

2. 追加する Trigger line から `or any counterexample search is inconclusive` を外してください。
   - `UNVERIFIED` な trace element の扱いと、`EQUIVALENT` のための反例探索不成立は分けるべき
   - もし吸収を認めるなら、`EQUIVALENT` ではなく「結論範囲の限定」か「追加探索継続」に倒す条件を明示する

3. Before/After の decision point を、`EQUIVALENT` と `NOT_EQUIVALENT` で対称に書き分けてください。
   - 例: `UNVERIFIED helper` は confidence 低下で吸収可、しかし `no counterexample exists` が未成立なら `EQUIVALENT` は確定しない、という境界を 2 分岐で示す
   - 新規必須ゲートを増やすのではなく、既存 Step 5 / Step 6 の役割分担を明確化するだけで足りる

承認: NO（理由: `counterexample search is inconclusive` を結論へ吸収する設計が、偽 EQUIV を招きうる片方向最適化だから）