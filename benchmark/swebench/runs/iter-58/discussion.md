# iter-58 proposal discussion

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は「観測される pass/fail outcome と内部 mechanism を分ける」という、既存 SKILL.md の D1（テスト pass/fail outcome による equivalence）と certificate-based per-test tracing の自然な精密化であり、特定の外部概念・用語・研究主張に強く依存していない。README.md / docs/design.md が述べる per-item tracing、formal conclusion、counterexample obligation とも整合する。

## 2. Exploration Framework のカテゴリ選定

カテゴリ C「比較の枠組みを変える」の選定は適切。

理由:
- 変更対象は探索順や証拠取得方法ではなく、per-test comparison の比較粒度そのもの。
- 現行の `Comparison: SAME / DIFFERENT outcome` が、内部挙動差と pass/fail 結果差を同じ語彙に畳み込みやすい点を直す変更である。
- 関数単位・モジュール単位への全面移行ではなく、既存 per-test loop 内で comparison の枠組みを二軸化するため、研究コアの per-test iteration を保つ。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT 側:
- 内部 mechanism が違っても、両変更が同じテストを同じ pass/fail outcome に導く場合、`Behavior relation: DIFFERENT mechanism; Outcome relation: SAME` と書ける。
- これにより、内部差をそのまま outcome 差へ昇格する偽 NOT_EQUIVALENT を減らす効果がある。

NOT_EQUIVALENT 側:
- 目的・説明・途中挙動が似ていても、片側の pass/fail result まで trace できない、または実際に異なる場合、`Outcome relation: UNVERIFIED` または `DIFFERENT` と明示できる。
- これにより、目的類似や機構類似だけで偽 EQUIVALENT に倒れるリスクを下げる。

片方向性の確認:
- 主効果は偽 NOT_EQUIVALENT 抑制にやや強いが、Outcome relation を verdict 根拠として明示するため、偽 EQUIVALENT 抑制にも作用する。
- ただし `UNVERIFIED` の導入は、使い方によっては保留寄りに働きすぎる懸念がある。現 proposal は「既存 Comparison 行の置換」として位置づけ、追加探索ゲートではないため許容範囲。

## 4. failed-approaches.md との照合

本質的な再演ではない。

- 原則 1「再収束を比較規則として前景化しすぎない」: NO。途中差分を弱めるために下流再収束を探す規則ではなく、既に per-test trace した outcome と mechanism を分離するだけ。
- 原則 2「未確定 relevance や脆い仮定を常に保留側へ倒す」: 軽微な懸念あり。ただし proposal は `UNVERIFIED` を verdict の広い fallback にするのではなく、pass/fail result が未追跡の場合の局所ラベルとして使う。必須ゲート増ではなく既存 Comparison の置換なので、過去失敗の本質的再演ではない。
- 原則 3「差分昇格条件を新しい抽象ラベルで強くゲート」: NO寄り。Behavior / Outcome は新しい二軸表現だが、差分を外部可視性や特定 assertion 形式へ再分類してから昇格させるゲートではない。D1 の outcome 根拠を明確化する局所置換。
- 原則 5「最初に見えた差分から単一追跡経路を既定化」: NO。次に読む artifact や trace 起点を固定していない。
- 原則 6「近接欄の統合で情報利得を潰す」: NO。統合ではなく、曖昧な単一欄を分解する変更。

## 5. 汎化性チェック

問題なし。

- 具体的な数値 ID: なし。`C[N]` や `D1` は SKILL.md テンプレートの自己引用であり、ベンチマーク ID ではない。
- リポジトリ名: なし。
- テスト名: なし。`Test: [name]` はテンプレート自己引用。
- 実装コード断片: なし。差分プレビューは SKILL.md 自身のテンプレート文言の置換であり、実リポジトリのコード引用ではない。
- 特定ドメイン・言語・テストパターン前提: なし。pass/fail outcome を基準にする比較は Go/JS/TS/Python 等に依存しない。

## 6. 推論品質の期待改善

期待できる改善は、結論に使う証拠の型を D1 に合わせる点にある。

現行の単一 `Comparison` 欄では、モデルが「違う実装経路」「違う中間値」「違う修正方針」を見つけた時点で `DIFFERENT outcome` と書きやすい。一方で、同じ目的に見える変更を見た時に pass/fail まで到達せず `SAME outcome` と書く危険もある。二軸化により、内部機構の差異は残しつつ、FORMAL CONCLUSION の根拠を pass/fail outcome に揃えやすくなる。

## 停滞診断（必須）

懸念 1 点:
- proposal は監査 rubric に刺さる説明（failed-approaches との照合、禁止方向の列挙）がかなり厚い。ただし差分プレビューに具体的な Trigger line があり、per-test comparison の出力欄が実際に変わるため、単なる説明強化だけではない。

failed-approaches 該当確認:
- 探索経路の半固定: NO。
- 必須ゲート増: NO。`Comparison` 行を二軸へ置換する payment が明示されている。
- 証拠種類の事前固定: NO。verdict 根拠を D1 の pass/fail outcome に揃えるだけで、読む証拠の種類や trace 起点を固定していない。

## compare 影響の実効性チェック（必須）

0) 実行時アウトカム差:
- compare 実行時に、per-test analysis の出力が `Comparison: SAME / DIFFERENT outcome` から、`Behavior relation` と `Outcome relation` の 2 行に変わる。
- 内部差のみの場合、ANSWER が NOT_EQUIVALENT へ早く倒れず、Outcome relation が SAME または UNVERIFIED として分離される。
- pass/fail まで追えていない場合、`SAME outcome` と書かず `Outcome relation: UNVERIFIED` が観測される。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
- Before: IF traced behavior に差が見える THEN 単一 `Comparison` 欄で `DIFFERENT outcome` と書きがち。
- After: IF traced behavior が違っても pass/fail result が同じか未追跡 THEN `Behavior relation: DIFFERENT mechanism; Outcome relation: SAME or UNVERIFIED` と分ける。
- 条件も行動も同じで理由だけ言い換えか？ NO。出力欄と verdict 根拠に使う relation が変わっている。
- Trigger line が差分プレビュー内に含まれているか？ YES。`Outcome relation: SAME / DIFFERENT / UNVERIFIED pass/fail result` が明示されている。

2) Failure-mode target:
- 対象は両方。
- 偽 NOT_EQUIV: 内部 mechanism 差を outcome 差と誤読する経路を減らす。
- 偽 EQUIV: 目的・機構の類似だけで pass/fail 同一とみなす経路を減らし、未追跡なら UNVERIFIED として露出させる。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？
- NO。proposal は候補として STRUCTURAL TRIAGE を検討して捨てており、実装対象は per-test comparison 欄。
- よって `impact witness` 要求の有無はブロッカーではない。

3) Non-goal:
- 新しい探索モードを増やさない。
- 次に読む artifact や trace 起点を固定しない。
- 特定の assertion boundary を全ケースの必須ゲートにしない。
- 既存 `Comparison` 行を置換するだけで、必須ゲート総量を実質的に増やさない。

## Discriminative probe（必須）

抽象ケース:
- 2 つの変更は同じテストを PASS させるが、一方は入力側で値を正規化し、もう一方は比較側で許容範囲を広げるため、内部 mechanism は異なる。
- 変更前は内部差を `Comparison: DIFFERENT outcome` と混同し、偽 NOT_EQUIV になりやすい。
- 変更後は `Behavior relation: DIFFERENT mechanism; Outcome relation: SAME pass/fail result` と分離できるため、必須ゲートを増やさず既存欄の置換だけで誤判定を避けられる。

## 停滞対策の検証（必須）

- 支払い（必須ゲート総量不変）の A/B 対応付け: 明示あり。
- `Payment: add MUST(...) ↔ demote/remove MUST("Comparison: SAME / DIFFERENT outcome")` とあり、追加ではなく置換として説明されている。

## 修正指示（最小限）

承認可能だが、実装時に以下だけ守ること。

1. `Outcome relation: UNVERIFIED` を追加探索や保留の広い既定動作にしない。あくまで per-test の pass/fail result が未追跡の場合の局所表記に留める。
2. 既存 `Comparison: SAME / DIFFERENT outcome` 2 箇所は残さず、提案どおり二軸行へ置換する。併記して必須行を増やす形にはしない。
3. FORMAL CONCLUSION では Behavior relation ではなく Outcome relation を D1 の根拠に使うことが伝わるよう、必要なら既存文の範囲内で短く統合する。

## 総合判断

提案は、監査 rubic への説明強化に寄りすぎるリスクを自覚しつつ、実際の compare 出力欄と decision point を変える Trigger line を持っている。failed-approaches.md の本質的再演ではなく、汎化性違反もない。EQUIVALENT / NOT_EQUIVALENT の両方向に作用し、特に単一 `Comparison` 欄の曖昧さによる誤昇格・誤同一視を減らす実効差がある。

承認: YES
