# Meta-template improvement rationale

## 停滞の診断

template_v15 の停滞は、単一のテンプレート不備というより、propose → discuss → implement の連鎖がそろって「実行時の分岐変更」より「監査に刺さる説明の整形」を強く最適化していることが主因です。

1. prompts/propose-normal.txt
   - 問題点: 外部資料（Objective.md / README.md / docs/*）参照を前提にしており、提案者の注意を SKILL.md の分岐文そのものではなく、カテゴリ正当化や説明補強へ拡散させていました。
   - 問題点: proposal の必須要件は多いものの、「説明追加だけで runtime が不変な案」を明示的に失格にする文が弱く、監査向けの文書としては整っていても compare の結論条件を変えない提案が残りやすい構造でした。
   - 停滞メカニズム: 提案が Trigger line / Payment / Discriminative probe を満たしても、実際には SKILL.md の IF/THEN 分岐を置換せず、表現の明確化や根拠説明の増補で終わると compare は伸びにくい。

2. prompts/propose-escape.txt
   - 問題点: 「構造改革」は許す一方で、構造変更が既存分岐の条件・行動を変えたかどうかを強く縛っていませんでした。
   - 停滞メカニズム: セクション再編や新見出し追加だけで proposal が成立しやすく、見た目は大きく変わっても、compare 実行時の既定動作が不変な“no-op 改革”が混ざりやすい。

3. prompts/discuss.txt
   - 問題点: compare 影響の実効性を確認する良い意図はある一方、Trigger line や Payment の書式欠落を自動不承認に近い扱いにしており、実際に分岐変更が具体な提案まで形式理由で落としやすい設計でした。
   - 問題点: 逆に、説明が整っていても runtime が変わらない提案を強く reject する一文が不足していました。
   - 停滞メカニズム: ディスカッション段階が「compare に効く提案を残すゲート」ではなく、「監査でつつかれにくい proposal 書式を通すゲート」へ寄りやすかった。

4. prompts/implement.txt
   - 問題点: proposal の差分プレビューとの literal 一致を強く優先しており、実際の Decision-point delta が SKILL.md 上で読めるかより、提案書の文面追従が優先されやすかった。
   - 停滞メカニズム: 実装段階で wording の最終最適化が抑制され、compare に効く“分岐として読める文”への仕上げが弱くなっていた。

総合すると、v15 は「proposal の体裁」「audit で説明しやすい痕跡」「preview との一致」に寄りすぎており、SKILL.md の既定分岐を実際に変える圧力が足りませんでした。これが compare の頭打ちと audit=0% の固定化を同時に招いていた、というのが今回の診断です。

## 変更の仮説

仮説: 各段階で「実行時アウトカム差」を最優先に再定義し、形式要件は runtime 分岐変更を支える補助条件へ格下げすれば、監査向けの説明強化だけの提案が減り、compare に効く提案が通過・実装されやすくなる。

期待する改善経路は次の通りです。

- propose 段階で、SKILL.md と failed-approaches.md のみに注意を集中させる
  → 外部資料で正当化を盛るより、SKILL.md のどの IF/THEN を置換するかに思考が寄る。

- propose 段階で Runtime delta check を明示する
  → 「変更前後で同じ結論・同じ追加探索なら無効」と自己検査させることで、説明-only 提案を前段で落とせる。

- discuss 段階で、書式欠落を自動否決条件から外しつつ、runtime 不変案を強く否決する
  → 形式に少し粗さがあっても compare に効く提案を残し、逆に綺麗だが効かない提案を落とせる。

- implement 段階で literal 一致より Decision-point delta の実装を優先する
  → proposal preview の文面をなぞるだけでなく、SKILL.md 上で分岐として発火する wording に寄せられる。

この変更群は、新しい制御フローや manifest 変更を入れず、既存ループの評価軸を「監査向けの説明」から「runtime 分岐変更」へ戻すため、compare 停滞の打破に最も直接的だと考えます。

## 変更したファイルと変更内容の要約

1. prompts/propose-normal.txt
   - 参照可能ファイルを SKILL.md / failed-approaches.md に縮小。
   - FORCED_CAT の扱いを外部参照不要に変更。
   - 「説明追加だけで runtime が変わらない案は不可」を明記。
   - proposal 必須項目に Runtime delta check を追加。
   - 外部資料で飾るより、SKILL.md の分岐文置換を優先する方針を追加。

2. prompts/propose-escape.txt
   - 参照可能ファイルを SKILL.md / failed-approaches.md に縮小。
   - セクション構造だけ変えて IF/THEN が不変な改革を失敗パターンとして明示。
   - proposal 必須項目に Runtime delta check を追加。

3. prompts/discuss.txt
   - 参照可能ファイルを proposal / SKILL.md / failed-approaches.md に縮小し、Web 検索を原則不要化。
   - Trigger line / Payment / Non-goal の書式欠落だけで落としすぎない方針を追加。
   - 一方で、SKILL.md の既存分岐文を置換せず runtime が変わらない案は承認しないと明記。
   - Trigger line 不足、Payment 不足を「修正優先事項」へ緩和し、必要以上の形式ゲート化を抑制。

4. prompts/implement.txt
   - proposal preview との literal 一致より、Decision-point delta が SKILL.md 上で実際の分岐として読めることを優先するよう変更。
   - rationale に `Observed runtime delta:` 1 行を追加させ、実装後も runtime 変化を明示させるようにした。

## 変更ファイル一覧

- prompts/propose-normal.txt
- prompts/propose-escape.txt
- prompts/discuss.txt
- prompts/implement.txt
