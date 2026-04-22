# iter-32 discussion

## 監査コメント

### 1. 既存研究との整合性
- 検索なし（理由: 提案は「semantic difference を即 verdict にしない」「test assertion まで trace してから結論化する」という一般原則の範囲で自己完結しており、特定の新規概念・外部理論への強い依拠がないため）
- README.md / docs/design.md / SKILL.md の研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）とは整合している。提案は compare の局所分岐を明確化するもので、コア構造の追加置換ではない。

### 2. Exploration Framework のカテゴリ選定
- カテゴリ E（表現・フォーマット改善）は適切。
- 実質は compare checklist の曖昧文言を、発火条件と禁止行動が明確な trigger line に置換する案であり、探索順の固定化や新モード追加ではない。
- さらに Payment が「既存 MUST の置換」として明示されており、G 的な簡素化要素もあるが、主作用は文言の具体化なので E 判定で妥当。

### 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側:
  - 変更前は semantic difference を見つけても「既存 tests に効かなそう」と早く丸めて偽 EQUIV に流れる余地がある。
  - 変更後は assertion boundary まで trace するか decisive UNVERIFIED link を明示するまで provisional 扱いとなるため、安易な no-impact 結論を減らせる。
- NOT_EQUIVALENT 側:
  - 変更前は semantic difference 自体を near-verdict evidence とみなし、偽 NOT_EQUIV に流れる余地がある。
  - 変更後は difference alone で NOT_EQUIV 化できず、diverging assertion か decisive UNVERIFIED link が必要になる。
- よって片方向最適化ではなく、premature verdict を両側で抑える対称作用がある。

### 4. failed-approaches.md との照合
- 本質的再演: ぎりぎり回避できている。
- 良い点:
  - 新しい抽象ラベルや CLAIM 形式の増設ではない。
  - checklist 1 行の置換であり、必須ゲートの純増を避けようとしている。
  - STRUCTURAL TRIAGE の早期 NOT_EQUIV を狭める案を non-goal と明記している。
- 懸念点:
  - failed-approaches.md 原則 3 の「差分の昇格条件を強くゲートしすぎない」にかなり近い。特に「difference alone is not yet a verdict」「assertion boundary または decisive UNVERIFIED link が出るまで verdict 不可」という書き方は、差分の結論利用条件を明示的に強める方向ではある。
  - ただし今回は structural difference 全般ではなく、詳細比較で semantic difference を発見した後の局所分岐に限定され、しかも既存の非対称文言を対称化する置換なので、failed-approaches.md 31 行目付近の一般失敗をそのまま再演しているとはまでは言えない。

### 5. 汎化性チェック
- 具体的な数値 ID, リポジトリ名, テスト名, 実コード断片: 含まれていない。ルール違反なし。
- 特定言語・特定フレームワーク依存: なし。
- 暗黙の前提:
  - 「assertion boundary」「test outcome witness」はテスト中心の compare に寄るが、これは SKILL.md の compare 定義 D1 と整合しており、特定ドメイン依存ではない。
- 総合すると汎化性は十分高い。

### 6. 全体の推論品質への期待効果
- semantic difference 発見時の扱いが曖昧だと、モデルは差分発見そのものを結論に誤変換しやすい。提案はこの一点を狙って verdict-ready evidence と exploratory signal を分離する。
- その結果、
  - 追加 tracing が必要な場面
  - UNVERIFIED を明示すべき場面
  - categorical verdict を出してよい場面
  の境界が明確になり、compare 実行時の分岐が安定する見込みがある。
- 変更量も小さく、研究コアを崩さずに runtime behavior を変えやすい。

## 停滞診断
- 懸念 1 点: 「provisional」「decisive UNVERIFIED link」という説明だけが強化され、実装時に “どの条件で verdict 保留へ倒すか” が曖昧なままだと、監査 rubic には刺さるが compare の実行時アウトカム差が弱くなるおそれはある。
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - semantic difference を見つけただけの時点では ANSWER を確定せず、追加 tracing または decisive UNVERIFIED link の明示へ分岐する。
  - LOW confidence の categorical verdict ではなく、UNVERIFIED を伴う保留寄り記述が増える可能性がある。

- 1) Decision-point delta:
  - Before: IF semantic difference is found and no traced assertion outcome exists yet, THEN the agent can still drift to EQUIVALENT/NOT_EQUIVALENT using the difference itself as near-verdict evidence.
  - After: IF semantic difference is found and no traced assertion outcome or decisive UNVERIFIED link exists yet, THEN the agent must keep it provisional and continue tracing / name the decisive link UNVERIFIED.
  - IF/THEN 形式で 2 行（Before/After）: YES
  - Trigger line（発火する文言の自己引用）: YES

- 2) Failure-mode target:
  - 対象: 両方
  - メカニズム: semantic difference の即時結論化を防ぎ、偽 EQUIV（差を見落として no impact 扱い）と偽 NOT_EQUIV（差があるだけで different 扱い）の両方を減らす。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
  - NO

- 3) Non-goal:
  - S1/S2 の早期構造判定ルールは変えない。
  - 新モード追加、探索順の半固定、証拠ラベルの新設はしない。
  - 既存 MUST の置換として扱い、必須ゲート総量を増やさない。

## 追加チェック
- Discriminative probe:
  - 抽象ケースは十分ある。helper 分岐に semantic difference があるが、既存 tests がそこへ到達するか未確認の場面で、変更前は「差があるから NOT_EQUIV」または「たぶん効かないから EQUIV」に寄りやすい。
  - 変更後は、同じ分量の checklist 置換だけで「assertion まで trace できるか / decisive UNVERIFIED link を示せるか」が分岐点になるので、誤った早期確定を避けやすい。

- 支払い（必須ゲート総量不変）:
  - YES。add MUST と remove MUST の対応付けが proposal 内で明示されている。

## 最小限の修正指示
1. 「decisive UNVERIFIED link」の意味を 1 句だけ補足してほしい。例: verdict を左右する未検証リンクであり、単なる未読関数ではない、と限定する。ここが曖昧だと compare 実行時に保留へ流れすぎる。
2. 変更差分プレビューの最終行「A verdict may use the difference only after ...」は、禁止規則の再重複になりやすい。Trigger line に統合し、追加 1 行を増やさない形に寄せた方がよい。

## 総合判断
- 提案は compare の実行時意思決定点を実際に変えており、監査向けの説明強化だけに留まっていない。
- failed-approaches.md 原則 3 に近い緊張はあるが、局所置換・両側対称化・支払い明示の3点により、本質的再演までは至っていない。
- 最大の成功条件は、UNVERIFIED を広い保留トリガーにせず「decisive link」に限定して実装すること。

承認: YES