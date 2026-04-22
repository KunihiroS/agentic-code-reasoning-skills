# iter-28 discussion

## 監査サマリ
- 既存研究との整合性: 検索なし（理由: 一般原則の範囲で自己完結。提案は compare 内の shortcut を trace-first に置換するもので、README.md / docs/design.md / SKILL.md の研究コアだけで評価可能）
- Exploration Framework カテゴリ選定: A は妥当。主作用点は「STRUCTURAL TRIAGE 後に即 verdict へ進むか、最初の trace を選ぶか」という推論順序・分岐構造の変更であり、情報取得法そのものや新しい表現形式の導入が主眼ではない。副次的に G 的な簡素化もあるが、主カテゴリは A でよい。
- 汎化性: 具体的な数値 ID、リポジトリ名、テスト名、実コード断片は含まれていない。SKILL.md 自身の文言引用のみで、R1 的には問題ない。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 変更前は S1/S2 の structural gap 検出だけで NOT_EQUIVALENT を返しうる。
  - 変更後は、その場では NOT_EQUIVALENT を出せず、最初の relevant test trace を必ず 1 本走らせる。
  - 観測可能な差は、ANSWER の即時 NO が減ること、追加探索要求が増えること、NOT_EQUIVALENT 時の根拠が「構造差のみ」から「diverging assertion つき」に変わること。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Before/After が実際の分岐として変わっているか: YES
    - Before: structural gap -> skip ANALYSIS -> NOT_EQUIVALENT
    - After: structural gap -> first relevant trace -> diverging assertion があれば NOT_EQUIVALENT、なければ追加探索/EQUIV 側検証へ
  - Trigger line の自己引用が差分プレビューにあるか: YES
    - "When S1/S2 finds a structural gap, trace the most relevant test through that gap before any NOT EQUIVALENT conclusion."

- 2) Failure-mode target:
  - 主対象は偽 NOT_EQUIV の削減。
  - ただし副次的に、真の NOT_EQUIV でも「どの assertion で割れるか」を先に作るので、根拠の薄い EQUIV 逃げも減らせる。したがって片方向だけではなく両方向に効く。
  - メカニズムは、構造差を verdict 証拠ではなく探索優先度に落とし戻し、比較判定を test-outcome divergence に再接続すること。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か?: YES
  - NOT_EQUIV の根拠が「ファイル差がある」だけに退化していないか: 退化を防ぐ方向
  - impact witness を要求しているか?: YES
    - 提案文の "diverging assertion" / "explicit PASS/FAIL split" がそれに当たる。

- 3) Non-goal:
  - 構造差の重要度を下げることではない。
  - 固定の assertion boundary へ全比較を写像することでもない。
  - structural gap を最初の trace 選択に使う点は維持し、探索経路の完全固定や新規必須ゲート増を避けている。

- Discriminative probe:
  - 抽象ケース: 片側だけ補助モジュール更新があるが、実テストでは guard によりその分岐へ到達しない。
  - 変更前は structural gap だけで偽 NOT_EQUIV を出しやすい。変更後は既存の per-test tracing を先に要求するため、同じ assertion outcome への再収束を確認して即時 NO を避けられる。
  - これは新ゲート追加ではなく、既存の「shortcut で終わる」必須文を外し、既存の traced-test 要件へ重心を戻す置換になっている。

- 支払い（必須ゲート総量不変）の明示:
  - YES
  - add MUST ↔ demote/remove MUST の対応付けが proposal 内で明示されているため、compare への実効差が曖昧ではない。

## EQUIVALENT / NOT_EQUIVALENT への作用
- EQUIVALENT 側:
  - 直接 EQUIV を出しやすくする提案ではないが、structural gap 由来の早すぎる NOT_EQUIV を止めるため、誤った NO を減らして正しい EQUIV 到達機会を増やす。
  - その結果、EQUIV 判定時の証拠は「構造差があるが outcome は割れない」まで具体化され、NO COUNTEREXAMPLE EXISTS と整合しやすくなる。

- NOT_EQUIVALENT 側:
  - 真の差分がある場合、単なる missing-file 指摘ではなく、どの test/assertion で outcome が分かれるかまで結論に載るので、NOT_EQUIVALENT の質が上がる。
  - 一方で、構造差だけで十分だった一部ケースでは探索 1 ステップ分のコストが増える。だが compare の定義 D1 が test outcome 基準なので、このコスト増は妥当な範囲。

- 片方向最適化の有無:
  - 片方向だけの最適化ではない。
  - 主作用は偽 NOT_EQUIV 抑制だが、NOT_EQUIVALENT を出す際の証拠要件も sharpen するため、両方向の判定品質に作用する。

## failed-approaches.md との照合
- 探索経路の半固定: NO
  - structural gap を「最初の trace 候補を選ぶ手掛かり」にするだけで、以後の探索経路を固定していない。
- 必須ゲート増: NO
  - 新規 must を足すというより、既存の早期 shortcut must を外して traced-test requirement へ置換している。proposal 内の Payment も明示的。
- 証拠種類の事前固定: NO
  - 新しい抽象ラベルや再記述形式を要求していない。要求するのは compare の元々の中核である traced test divergence / assertion witness であり、別種の証拠フォーマット追加ではない。

補足:
- failed-approaches 原則 2 の「未確定なら広く保留へ倒す」失敗とは異なる。提案は常時保留化ではなく、structural gap 発見時に 1 本目の discriminative trace へ送る局所的分岐変更である。
- 原則 3 の「新しい抽象ラベルや必須の言い換え形式で強くゲート」にも当たりにくい。Trigger line は実装の発火条件を明確にする自己引用であり、新しい分類層ではない。

## 研究コアとの整合
- README.md と docs/design.md が強調する研究コアは、番号付き前提、仮説駆動探索、手続き間トレース、反証である。
- 本提案は compare だけにある structural shortcut を、研究コア側の traced evidence requirement に揃え直すもの。
- 特に docs/design.md の「per-item iteration as the anti-skip mechanism」と整合的で、per-test iteration を弱める shortcut を抑制する点は自然。

## 停滞診断
- 懸念点 1 つだけ:
  - 監査 rubric には刺さりやすいが、実装時に "first relevant test" の選び方が曖昧なままだと、単に説明だけ丁寧になって compare 実行の分岐が安定して変わらない恐れはある。ここは Trigger line に続けて「most discriminative / most directly connected to the gap」程度の選定基準を 1 句で添えるとよい。

## 全体の期待効果
- 早すぎる structural shortcut を減らし、compare の定義 D1（test outcome 同一性）に判定根拠を再接続できる。
- 偽 NOT_EQUIV を下げつつ、真の NOT_EQUIV では assertion-level witness を伴うため、結論の説明責任が上がる。
- 変更範囲は Compare セクション内の置換に限定され、研究コアや他モードへの回帰リスクは比較的小さい。

## 修正指示（最小限）
1. "first relevant test" の選定基準を 1 句だけ足す。
   - 追加するなら、既存の抽象説明を増やすのでなく、"most relevant" を "most directly connected to the structural gap" に置換して具体化する。
2. After 側の文に、trace 後の分岐先を短く固定する。
   - 例: "if no diverging assertion is reached, continue ANALYSIS rather than concluding NOT EQUIVALENT"。
   - 新行追加ではなく、既存 After 文の後半を置換して十分。

## 結論
- 監査観点では十分に PASS 下限を満たしている。
- compare の実行時アウトカム差も明確で、failed-approaches.md の本質的再演でもない。

承認: YES