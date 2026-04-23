# Iteration 42 Discussion

## 総評
この提案は、既存の compare テンプレートの「semantic difference を見つけた後の既定分岐」を変えるもので、結論条件そのものを狭義化する案ではありません。差分発見後に広域比較へ戻りやすい停滞点を、共有 relevant test の両側トレースへ先に寄せる提案として読めます。変更対象も compare 内の局所的な順序規則に留まっており、研究コア（premises / hypothesis-driven exploration / interprocedural tracing / refutation）を崩していません。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md と照合すると、論文由来のコアは「具体項目ごとの iteration により premature conclusion を防ぐ」「差分を見つけたら具体 trace へ落とす」点にあります。本提案は per-test iteration を compare 内で前倒しするだけで、別の理論や外部概念を持ち込んでいません。

## 2. Exploration Framework のカテゴリ選定
判定: 適切（A. 推論の順序・構造を変える）

理由:
- 提案の中心は「semantic difference 発見後の次アクション順序」を変えること。
- 新しい証拠型や分類ラベルを足すのではなく、既存の test trace を後段注意事項から前段既定分岐へ再配置している。
- したがって B（情報取得法）や D（自己チェック強化）よりも、A の「実行順序の入れ替え」に最も素直に該当する。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - semantic difference を見つけた時点で、広域の structural/high-level comparison を続ける出力が減り、先に「同一 shared relevant test の両側 trace」を書く挙動が観測可能に増える。
  - EQUIVALENT を出す前に、少なくとも 1 本の paired per-test trace が先に現れやすくなる。
  - NOT_EQUIVALENT では、counterexample の到達が「後段の補強」ではなく「早期の主要証拠」になりやすい。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか？ YES
  - 実効差もある。Before は「semantic difference があっても test-impact tracing を後回しにできる」、After は「paired test trace が未実施なら先にそれを行う」で、条件も行動も変わっている。理由の言い換えだけではない。

- 2) Failure-mode target:
  - 主対象: 偽 EQUIVALENT
  - 副対象: 偽 NOT_EQUIVALENT の一部も抑制しうる
  - メカニズム: 差分検出後に downstream の再収束説明や広域比較へ流れてしまう前に、同一 test で assertion-level divergence の有無を確認させるため。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ YES
  - `impact witness` を要求しているか？ YES
  - 根拠: 「trace one shared relevant test through that differing path on both changes」という要求が、少なくとも 1 つの test-level witness を先に取りに行く形になっている。単なるファイル差ベースの早期 NOT_EQUIV への退化ではない。

- 3) Non-goal:
  - 結論条件を assertion boundary / oracle 可視性 / VERIFIED 接続へ狭めること自体はしない、と明記している。
  - 新しい抽象ラベル追加、必須ゲート増、証拠種類の事前固定を避ける境界がある。
  - Payment も明示されており、MUST を 1 つ足す代わりに「STRUCTURAL TRIAGE (required before detailed tracing)」を demote/remove する対応付けがある。

- 追加チェック: Discriminative probe
  - あります。抽象ケースとして「shared downstream validator に再収束するが、前段 helper 条件差で特定入力時に assertion 結果が分かれる」ケースを置き、Before は偽 EQUIV に流れやすく、After は同一 test の両側 trace で回避できると示している。
  - しかも説明は「新ゲート追加」ではなく、既存の `trace at least one relevant test` の前倒し・再配置として書かれており、運用ルールに合致します。

- 追加チェック: 支払い（必須ゲート総量不変）
  - 明示あり。A/B の対応付けは十分明確です。

## 4. EQUIVALENT / NOT_EQUIVALENT への作用
### EQUIVALENT 側
- 改善見込みは高いです。現行 SKILL.md では、semantic difference を見つけても structural triage first と high-level comparison が前景化され、差分が「結局 downstream で吸収されるだろう」という説明に流れやすい。
- 本提案では、EQUIVALENT を出す前に少なくとも 1 本の shared relevant test の両側トレースを要求するため、「差分はあるがテスト結果は本当に同じか」の検証が先に来る。これにより偽 EQUIV を減らす方向に効く。

### NOT_EQUIVALENT 側
- 片方向最適化ではありません。真の NOT_EQUIVALENT でも、差分を通る shared relevant test を早く追うことで counterexample を早期に具体化しやすくなります。
- しかも structural gap による早期結論そのものを禁止しているわけではなく、structural triage の「required before detailed tracing」を弱めるだけなので、明白な構造差の探索補助としての価値は残る。
- よって NOT_EQUIVALENT 判定を不必要に鈍らせる危険は限定的です。

### 変更前との実効差分
- 変更前: semantic difference 発見後でも、広域の構造比較・再収束説明・high-level semantic comparison を続ける余地が大きい。
- 変更後: semantic difference 発見後、paired test trace が未実施ならそれが次アクションの既定になる。
- この差は EQUIVALENT にしか効かない片方向ルールではなく、「差分を見つけた後の探索の進み方」自体を変えるため、両 verdict に作用する。

## 5. failed-approaches.md との照合
### 本質的再演か
判定: いいえ

理由:
- 原則1「再収束を比較規則として前景化しすぎない」に対して、本提案は逆方向です。再収束説明を早く組み立てるのではなく、その前に test-level trace を入れる。
- 原則2「未確定なら広く保留側へ倒す既定動作」も再演していません。UNVERIFIED 既定や非確定化の新ゲートを足していない。
- 原則3「差分の昇格条件を新しい抽象ラベルや必須形式で強くゲートしすぎない」にも当たりにくいです。paired trace は新ラベルではなく既存の test trace の順序変更です。
- 原則4「証拠十分性チェックを confidence 調整へ吸収しすぎない」とも衝突しません。むしろ concrete trace を前倒しするため、premature closure を抑える方向です。

### 停滞診断（必須）
- 懸念点を 1 つだけ挙げるなら、「shared relevant test」の選び方が proposal 上ではまだ少し広く、実装次第では監査向け説明だけ整って compare 実行時には従来どおり広域比較へ戻る余地が残る点です。ただし Trigger line と Before/After が十分具体なので、現時点では致命的ではありません。

### failed-approaches 該当性（YES/NO）
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足:
- `shared relevant test` は compare の既存証拠単位（relevant test）を前倒しするだけで、新しい証拠型の固定ではない。
- Payment により triage-first の必須性を下げているため、純増の mandatory gate にもなっていない。

## 6. 汎化性チェック
判定: 問題なし

- 具体的なベンチマーク ID、特定リポジトリ名、テスト名、実コード断片は含まれていません。
- 含まれている固有の文字列は SKILL.md の自己引用であり、Objective.md の R1 減点対象外に該当します。
- `~200 lines` は既存 SKILL の一般的しきい値の自己引用であり、ベンチマーク固有 ID ではありません。
- ドメイン依存性も薄いです。提案は「差分発見後に共有 relevant test を両側で追う」という一般的 compare 原則で、特定言語・特定フレームワーク・特定テストパターンへの暗黙依存は強くありません。

## 7. 全体の推論品質への期待効果
- semantic difference を見つけた瞬間に、最も識別力の高い next step を選びやすくなる。
- 差分があるのに downstream 再収束の説明へ流れてしまう premature closure を減らせる。
- EQUIVALENT 判定では「本当に test outcome が同じか」の確認が増え、NOT_EQUIVALENT 判定では counterexample の具体性が上がる。
- 変更規模が小さく、しかも置換中心なので、研究コアを保ったまま compare の実行順序だけを改善する提案としてバランスがよい。

## 最小限の修正指示
1. `shared relevant test` の選定基準を 1 句だけ補強してください。例: 「the nearest shared relevant test that traverses the differing path」程度で十分です。追加ではなく Trigger line 内の名詞句置換で足ります。
2. 差分プレビューの After 行に「before any further high-level comparison or equivalence claim」とあるので、これと Payment の関係が分かるよう、`STRUCTURAL TRIAGE` を optional/early-guidance 化する文言を 1 行に圧縮して一貫させてください。新規行追加より統合を優先してください。

## 結論
この proposal は、監査 rubic に刺さる説明のためだけの変更ではなく、compare 実行時の分岐を実際に変える提案になっています。failed-approaches.md の本質的再演でもなく、片方向最適化でもありません。細部の wording は少し磨けますが、差し戻しにするほどではありません。

承認: YES
