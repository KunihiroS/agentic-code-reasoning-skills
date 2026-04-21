# Iteration 6 — discussion

## 総評
提案の主眼は、compare の研究コアを変えずに、Step 5.5 の「NO が 1 つでもあれば Step 6 に進めない」という重複した完了性ゲートを外し、未検証リンクは Step 6 の結論で明示する方へ置換する点にあります。これは「認知負荷の削減（G）」として自然で、Objective.md の G カテゴリ「簡素化・削除・統合」に合致しています。特に、研究コアとして保護されている番号付き前提・仮説駆動探索・手続き間トレース・必須反証は維持対象として明示されており、削減対象がその外側の重複ゲートに限定されている点は妥当です。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が強調する研究コアは、証拠先行・明示的前提・逐次トレース・反証可能性です。本提案はそのコアを置換しておらず、「certificate の完備性を高めるための補助ゲート」が compare 実行時に過剰な保留や穴埋め捏造を誘う、という運用上の負荷を下げようとしています。よって、論文由来の中核メカニズムを外して別方式へ寄せる提案ではありません。

## 2. Exploration Framework のカテゴリ選定
判定: 適切

理由:
- 提案が変えるのは新しい探索経路ではなく、既存フロー中の重複ゲートの削除・統合です。
- 「Payment」で add/remove を対応付け、必須総量を増やさずに compare の詰まり方だけを変える設計になっています。
- A/B/C/D/F よりも、G の「重複する指示や冗長な説明を統合・圧縮」に最も近いです。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 観測可能に変わるのは、pre-conclusion self-check に NO が残っても、コア主張が既に追跡済みなら「追加探索に戻る」ではなく「UNVERIFIED を明示して結論を出す」分岐へ進める点です。
  - その結果、ANSWER の出し方、結論保留の頻度、CONFIDENCE の下げ方が変わります。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES
  - 評価:
    - Before は「checklist NO → Step 6 禁止 → reopen search/repair」
    - After は「non-core link が UNVERIFIED でも traced test-outcome claim が支持済み → uncertainty 明示付きで結論」
    - これは理由の言い換えではなく、分岐条件と行動の両方が変わっているため、compare 実効差は明確です。

- 2) Failure-mode target:
  - 主対象: 両方。ただし一次効果は偽 NOT_EQUIV / 過度な保留 / 穴埋め捏造の抑制に強く、二次効果として偽 EQUIV も抑えうる。
  - メカニズム:
    - 偽 NOT_EQUIV / 過保留: 「未検証リンクが 1 個あるだけで戻る」挙動を弱め、局所不確実性を結論側で吸収する。
    - 偽 EQUIV: checklist を埋めるための補完捏造を減らし、未確認部分を未確認のまま露出させる。
  - ただし効果は完全対称ではなく、EQUIV 側・保留側の改善寄りです。NOT_EQUIV 側には、周辺リンク未検証のせいで grounded な差分結論を出せないケースで補助的に効く、という位置づけです。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か?: NO
  - よって impact witness 要件の退化懸念は今回の主論点ではありません。
  - なお Non-goal で structural triage / assertion boundary / refutation を変えないと明示しており、NOT_EQUIV が「単なるファイル差」へ退化する方向ではありません。

- 3) Non-goal:
  - 探索経路の半固定を増やさない
  - 必須ゲート総量を増やさない（Payment あり）
  - 証拠種類を新たに固定しない
  - structural triage, assertion boundary, refutation obligation は不変

## 追加チェック
- Discriminative probe:
  - 提案には抽象ケースがあり、主要な traced test-outcome claim は十分に立っているが、末端の補助ライブラリ 1 箇所だけ source unavailable で UNVERIFIED という状況を示しています。
  - 変更前は Step 5.5 を埋めるために探索延長か、弱い仮定の VERIFIED 化が起きやすい。
  - 変更後は同じ証拠量のまま UNVERIFIED を開示して MEDIUM/LOW confidence の結論へ進めるため、compare の意思決定差が具体です。

- 「支払い（必須ゲート総量不変）」の A/B 対応付け:
  - 明示あり。add MUST と remove MUST が proposal 内で 1 対 1 に示されています。

## 4. EQUIVALENT / NOT_EQUIVALENT への作用
### EQUIVALENT 側
最も直接に効きます。現行 Step 5.5 では、主要な比較経路が追跡済みでも、周辺の未検証が残るだけで修復探索が再起動しやすく、結果として unnecessary hold や、埋めるための推測が混入しやすい。提案後は「反証不能ではなく、未確認を明示したうえで EQUIVALENT 判定を出す」余地が生まれるため、偽 NOT_EQUIV や保留過多を下げる方向に働きます。

### NOT_EQUIVALENT 側
作用はあるが弱めです。NOT_EQUIVALENT は既に counterexample と diverging assertion の要求があるため、結論の核は Step 5.5 より前でほぼ固まることが多い。したがってこの変更だけで NOT_EQUIVALENT の判定ロジックが大きく変わるわけではありません。

ただし、差分の本筋が trace 済みなのに、周辺の UNVERIFIED が残ったために Step 5.5 で足止めされるケースでは、必要以上の再探索なしに grounded な NOT_EQUIVALENT を出せるようになる余地があります。よって片方向専用ではないが、実効差は EQUIVALENT/保留側により強い、という評価です。

## 5. failed-approaches.md との照合
判定: 本質的再演ではない

理由:
- 原則 1「再収束を比較規則として前景化しすぎない」:
  - 本提案は再収束規範を追加していません。むしろ追加の修復探索を減らし、局所不確実性を結論へ送る設計です。
- 原則 2「未確定な relevance を常に保留側へ倒す既定動作を増やしすぎない」:
  - 本提案は保留側 fallback を増やすのではなく、逆に NO が出たら修復探索へ戻る既定動作を緩めています。

よって、表現替えで同じ失敗を再演しているとは言いにくいです。

## 6. 汎化性チェック
判定: 問題なし

- proposal 中に、具体的な benchmark case ID、リポジトリ名、テスト名、関数名、コード断片の引用は含まれていません。
- 引用されているのは SKILL.md 自身の既存文言・予定文言であり、Objective.md の R1 が許容する自己引用の範囲です。
- ドメイン・言語・特定テストパターンへの暗黙依存も弱く、UNVERIFIED disclosure と conclusion-local handling は任意言語の静的比較に適用できます。

## 7. 全体の推論品質への期待効果
期待できる改善は、証拠量を増やすことではなく「同じ証拠量から、より正直で観測可能な結論を出せる」ことです。具体的には:
- checklist 完備のための補完捏造を減らす
- 末端の未確認に引きずられた探索延長を減らす
- 主要 claim が traced 済みなら、未確認は confidence へ反映して結論を出す
- その結果、compare 実行時の保留過多と無駄な再探索を減らす

## 停滞診断（必須）
- 懸念 1 点:
  - 「監査 rubric に刺さる説明強化」だけで compare が変わらない提案ではないか、という懸念は比較的低いです。理由は、proposal が Step 5.5 の NO 発生時の実行分岐そのものを `reopen` から `disclose-and-conclude` に変えると明示しており、実行時アウトカム差が観測可能だからです。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## 懸念点
最大の注意点は、実装時に Step 5.5 の「修復ゲート」だけでなく、そこで担っていた最小限の健全性確認まで一緒に落としてしまうと、compare 影響ではなく単なる discipline 低下になることです。proposal 自体は Payment と Non-goal でその回避策を書いているため、現段階では致命的ブロッカーではありませんが、実装時は「削るのは reopen gate であって、claim beyond evidence の抑制まで捨てない」ことを守る必要があります。

## 修正指示（最小限）
1. Step 5.5 を丸ごと削除するのではなく、「reopen を強制する文」だけを削除し、claim beyond evidence を抑える最小の確認文は Step 6 へ統合する形を明記してください。
2. proposal 内で「non-core link」の定義を 1 行だけ補ってください。例: traced test-outcome claim を変えない周辺リンク、という程度で十分です。
3. NOT_EQUIVALENT 側への作用が補助的であることを 1 文だけ明記してください。両方 target と言うなら、非対称性を先に認めた方が監査上ぶれません。

承認: YES