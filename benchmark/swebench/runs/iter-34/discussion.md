# iter-34 discussion

## 総評
この提案は、compare の直前にある独立 mandatory gate を、既存の compare certificate の十分性判定へ吸収する案として一貫しています。目的が「監査で安全そうに見せる説明追加」ではなく、Step 6 に進める条件そのものを変える点にあり、compare の実行時アウトカム差も比較的明確です。failed-approaches.md が禁じているのは「未解決なら広く保留へ倒す既定動作の追加」であり、本提案はむしろその重複ゲートを減らす方向なので、本質的再演には当たりません。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が強調する研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証です。提案はこれらを削らず、Step 5.5 の重複自己監査だけを compare certificate の sufficiency 判定に寄せ替えるものなので、研究コアとの整合性は保たれています。

## 2. Exploration Framework のカテゴリ選定
カテゴリ G（認知負荷の削減）は適切です。
理由:
- 追加ではなく、重複 mandatory gate の削除・統合が主眼だから
- 研究コアを残したまま、compare 直前のチェック総量を減らす案だから
- Objective.md の G の注意書き「研究のコア構造は削除しない」にも抵触しないから

A/D/E でも説明は可能ですが、今回の本質は「自己チェックの強化」ではなく「重複した結論前ゲートの簡素化」なので、G が最もしっくりきます。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
片方向最適化には見えません。作用は両方向です。

- EQUIVALENT 側:
  既に per-test trace と no-counterexample が揃っているのに、周辺の非決定的 UNVERIFIED が残っただけで再探索に戻る流れを減らせます。これにより、不要な保留や過剰な CONFIDENCE 低下を減らせます。
- NOT_EQUIVALENT 側:
  既に diverging assertion まで到達しているのに、周辺の未確認項目のために結論を寝かせる流れを減らせます。これにより、十分な counterexample があるのに追加探索へ引き戻される停滞を減らせます。
- 実効差分:
  変更前は「独立 checklist が全部 YES か」が Step 6 進行条件になっている。変更後は「compare certificate が verdict を既に決めているか」が進行条件になる。これは理由の言い換えではなく、分岐条件の変更です。

## 4. failed-approaches.md との照合
本質的再演ではありません。むしろ原則 2 の回避策として妥当です。

照合:
- 原則 2「未確定な relevance や脆い仮定を、常に保留側へ倒す既定動作にしすぎない」
  -> Step 5.5 はまさに「未解決項目が 1 つでもあると再探索へ戻す」構造を持っており、proposal はその重複ゲートを外す方向です。
- 原則 3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」
  -> proposal は新しい抽象ラベルや必須分類を足していません。既存 certificate sufficiency に戻しているだけです。
- 原則 1「再収束を比較規則として前景化しすぎない」
  -> 提案は再収束規則の追加ではないため非該当です。

## 5. 汎化性チェック
汎化性違反は見当たりません。

- 具体的な数値 ID: なし
- ベンチマーク対象リポジトリ名: なし
- テスト名: なし
- 実コード断片: なし
- 特定言語・特定フレームワーク前提: なし

暗黙の前提も比較的汎用的です。"compare certificate already establishes identical or different test outcomes" という条件は、SKILL.md の compare 定義そのものに依存しており、特定の言語・ドメイン・テスト様式には依存していません。

## 6. 全体の推論品質への期待効果
期待できる改善は「証拠生成」そのものより、「十分な証拠があるのに結論へ進まない停滞」の削減です。

具体的には:
- 重複チェックによる再探索の既定化を弱める
- 非決定的な未解決を verdict 条件から切り離し、CONFIDENCE へ送れるようにする
- compare の出力を、checklist 完充足ではなく test-outcome sufficiency に寄せる
- 分析終盤での整形・自己監査ループを減らし、既存証拠の判別力を素直に使えるようにする

## 停滞診断
- 懸念 1 点だけ:
  この提案は「監査 rubric に刺さる簡素化説明」にも見えうるが、今回は Decision-point delta と Trigger line があり、Step 6 に進む条件を実際に変えているため、単なる説明強化だけには留まっていません。

- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  verdict 非決定的でない未解決が残っていても、追加探索に戻らず ANSWER を出し、未解決を CONFIDENCE/uncertainty に送るケースが増える。

- 1) Decision-point delta:
  Before: IF Step 5.5 の 4 項目のどれかが NO THEN Step 6 を止めて追加探索/修復へ戻る。
  After: IF compare certificate が同一/相違の test outcome を既に確立し、残る未解決が非決定的 THEN Step 6 に進み未解決は CONFIDENCE に送る。
  IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  Trigger line（発火する文言の自己引用）があるか？ YES

- 2) Failure-mode target:
  主対象は両方。偽 EQUIV / 偽 NOT_EQUIV そのものより、十分な証拠があるのに過度な保留や不要再探索へ流れる failure mode を減らす。その結果として、両側の正しい verdict 到達率を上げる狙い。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO

- 3) Non-goal:
  構造差の昇格条件、早期 NOT_EQUIV 条件、観測境界、証拠形式の新設は変えない。重複 mandatory gate の削除・統合に限定する。

- Discriminative probe:
  抽象ケースとして、主要テストの assertion boundary までの trace は両変更で既に確定しており、差分の有無も判定済みだが、周辺の補助関数 1 個だけ UNVERIFIED のまま残る場合を考える。変更前は self-check NO により追加探索へ戻りやすい。変更後は、その補助関数が verdict 非決定的なら CONFIDENCE を下げつつ結論できるので、誤った停滞を避けられる。

- 追加チェック（支払い）:
  A/B の対応付けは明示されています。add 1 行 ↔ remove 1 行の payment が proposal 内で明確です。

## 留意点
承認可能ですが、実装時は次の 2 点だけ明確化した方がよいです。

1. "non-decisive uncertainty" の判定根拠を、compare certificate で既に要求されている per-test outcome / counterexample / no-counterexample に結び付けること。
   - 追加するなら新しい必須ゲートではなく、Trigger line の後半を "...when no remaining uncertainty changes any traced test outcome" のように少しだけ具体化するのがよいです。

2. Step 5.5 を丸ごと削るなら、そこで守っていた「evidence beyond support を書かない」趣旨が完全に蒸発しないよう、Step 6 の既存 bullet に軽く吸収しておくこと。
   - ただし支払い総量は維持し、別の mandatory checklist を再増設しないこと。

## 結論
この proposal は、compare の実行時分岐を実際に変える提案になっています。重複 self-check を減らして sufficient evidence から verdict へ進みやすくする方向で、failed-approaches.md の本質的再演でもありません。逆方向の悪化懸念はゼロではないものの、提案が structural triage や早期 NOT_EQUIV を触っていないため影響範囲は比較的限定的です。

承認: YES
