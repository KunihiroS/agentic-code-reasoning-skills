# iter-43 discussion

## 総評
提案は、compare の結論規則そのものを変えるのではなく、relevant test の取得順序を「直接参照中心」から「direct reference → caller/importer expansion」へ置き換えるものです。これは Exploration Framework では B. 情報の取得方法を改善する に素直に属します。変える対象が「何を結論するか」ではなく「次に何を探すか」の分岐であり、proposal 内でも Payment・Decision-point delta・Trigger line が明示されているため、監査に刺さる説明だけでなく compare 実行時の行動差も比較的はっきりしています。

## 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が強調する研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証です。今回の提案はこのコアを削らず、Step 3/compare D2 の探索優先順位だけを調整するため、研究の本筋からの逸脱は見えません。特に docs/design.md の「per-item iteration as the anti-skip mechanism」とも整合的で、relevant test の取りこぼしを減らして per-test iteration の入力を改善する提案として読めます。

## Exploration Framework のカテゴリ選定
判定: 適切

理由:
- 主作用点は compare D2 の「関連テストの見つけ方」です。
- 提案は新しい判定ラベルや新しい結論ゲートの追加ではなく、探索の優先順位変更です。
- Objective.md のカテゴリ定義では「何を探すかではなく、どう探すかを改善する」「探索の優先順位付けを変える」が B に含まれており、今回の proposal と一致します。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 直接参照の薄い変更で、compare 実行時に追加で caller/importer/re-export を読みに行くようになる。
  - その結果、pass-to-pass tests を早々に irrelevant/N/A 扱いせず、追加探索要求・UNVERIFIED 回避・最終 ANSWER/CONFIDENCE が実際に変わりうる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Before/After が分岐として変わっているか？ YES。Before は direct reference 不足時でも構造/高レベル比較へ進みやすい、After は caller/importer expansion を次アクションとして要求する。
  - Trigger line の自己引用が差分プレビュー内にあるか？ YES

- 2) Failure-mode target:
  - 対象: 偽 EQUIV / 偽 NOT_EQUIV の両方
  - メカニズム: shared helper・wrapper・re-export 経由の実到達テストを拾えず、差分影響を過小評価して偽 EQUIV、逆にテスト到達性が薄いまま structural/high-level 読みで差分を過大評価して偽 NOT_EQUIV、の双方を減らす狙い。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO
  - 早期 NOT_EQUIV 条件を強めたり狭めたりしていないため、この論点の主リスクは低い。

- 3) Non-goal:
  - 早期 NOT_EQUIV 規則そのものは変更しない。
  - UNVERIFIED 既定分岐を増やさない。
  - 新ラベル追加や単一アンカー固定ではなく、探索順位の差し替えに留める。

## EQUIVALENT / NOT_EQUIVALENT 双方向への作用
### EQUIVALENT 側
改善が効く場面は、差分が helper や内部関数にあり、テストが wrapper 経由でしか届かないケースです。変更前は pass-to-pass relevance が痩せたまま「反例が見つからない」へ寄りやすく、実質的には未探索由来の偽 EQUIV が起きえます。変更後は caller/importer expansion によって実際に到達するテストを回収しやすくなり、EQUIVALENT 判定の前提が厚くなります。

### NOT_EQUIVALENT 側
同じ探索強化は、差分が本当に既存テストへ伝播する場合の観測を増やすので、differing assertion まで届く trace を作りやすくします。したがって偽 EQUIV を減らすだけでなく、真の NOT_EQUIVALENT をより証拠付きで言いやすくなる効果があります。

### 片方向最適化の有無
片方向最適化ではありません。理由は、提案が verdict の閾値を片側に傾けるのでなく、「relevant tests の回収漏れを減らす」ことで両側の基礎証拠を増やすからです。特に proposal 本文でも Non-goal として early NOT_EQUIV の操作や UNVERIFIED 既定化を避けており、片側だけを安全側/保守側に寄せる設計ではありません。

## failed-approaches.md との照合
総評: 本質的再演ではない可能性が高い。

- 原則1「再収束の前景化」: NO
  - 下流で吸収される説明を強める提案ではない。
- 原則2「保留側への既定化」: NO
  - direct reference が薄いときに保留へ倒すのでなく、次の探索先を caller/importer search に変えている。
- 原則3「新しい抽象ラベル/証拠昇格ゲート」: NO
  - external/internal のような新分類を導入せず、既存の relevant test 探索を具体化している。
- 原則4「終盤チェックを confidence に吸収」: NO
  - 終盤 self-check を削らず、前段の探索取得を改善する提案である。
- 原則5「最初の差分から単一追跡経路を固定」: NO
  - むしろ direct reference だけに頼る狭い探索から、caller/importer/re-export へ広げる方向。

## 停滞診断
- 監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
  - 軽微にある。理由は、実装時に caller/importer expansion が単なる説明文の追加に留まると、実際の探索量が増えず「関連テストをちゃんと探したと言語化するだけ」になる危険があるため。ただし今回は Trigger line と Before/After の次行動差が書かれているので、懸念は主ではない。

- 「探索経路の半固定」該当: NO
- 「必須ゲート増」該当: NO
- 「証拠種類の事前固定」該当: NO

補足: caller/importer/re-export を優先候補として明示しているが、これは単一アンカー固定ではなく、direct reference 不足時の補助探索先の列挙に留まっている。

## 汎化性チェック
判定: 問題なし

- proposal 文中に具体的な数値 ID、ベンチマーク対象リポジトリ名、テスト名、実コード断片は見当たりません。
- 含まれるのは SKILL.md 自身の文言引用と、helper / wrapper / caller / importer / re-export といった一般概念です。
- 言語依存性は限定的です。re-export という語は一部言語で目立つものの、caller/importer という一般化された語と併記されており、特定言語専用の規則にはなっていません。
- 暗黙のドメイン前提も強くありません。direct reference が薄いが呼び出し経路では影響する、という現象は多言語・多リポジトリで起こりうるためです。

## Discriminative probe
抽象ケース: 変更対象は内部 helper の戻り値条件だけ異なるが、既存テストは helper 名を直接呼ばず、公開 API を通じてのみその helper に到達する。変更前は direct test reference が薄いため pass-to-pass relevance を外しがちで、実際には差がテストへ届くのに EQUIV 寄り、または構造差だけ見て NOT_EQUIV 寄りにぶれる。変更後は direct-reference 不足時に caller/importer expansion を必須化するので、公開 API 側テストを回収して実到達経路で判定でき、誤判定を避けやすい。

この probe は、新ゲート追加ではなく D2 と checklist の置換で説明されており、総量不変の範囲に収まっています。

## 支払い（必須ゲート総量不変）の確認
判定: 明示あり

Proposal は
- add MUST: 「If direct test references are absent, expand outward through callers/importers before marking pass-to-pass tests irrelevant or N/A.」
- demote/remove MUST: 「Identify fail-to-pass AND pass-to-pass tests」
の対応付けを明示しており、A/B の支払いが見えます。ここは停滞対策上かなり重要で、今回の proposal は条件を満たしています。

## 期待される推論品質の向上
- relevant tests の取得漏れを減らし、per-test 分析の入力品質を改善できる。
- pass-to-pass relevance の誤除外が減るため、EQUIVALENT 判定の過信を抑えやすい。
- 一方で structural/high-level 読みへの早すぎる寄り道も減るため、NOT_EQUIVALENT も assertion 近傍の具体証拠で支えやすい。
- 変更規模が 4-6 行想定で局所的なので、研究コアや既存の guardrail を壊しにくい。

## 最小限の修正指示
1. D2 の置換文では「caller/importer/re-export」を exhaustive な必須集合に見せず、「e.g. callers, importers, re-export chains」のように例示化して、証拠種類の事前固定に誤読される余地を減らしてください。
2. checklist 側の新文言は「pass-to-pass relevance open until search is exhausted」だけだと長く曖昧なので、「direct-reference search and outward call-path search are exhausted」のように exhausted の対象を短く特定してください。

## 結論
承認: YES