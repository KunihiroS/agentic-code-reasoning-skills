# iter-39 proposal discussion

## 総評
提案の狙い自体は明確で、compare における「STRUCTURAL TRIAGE からの早期 NOT_EQUIV 断定」の誤爆を減らしたい、という実行時アウトカム差も書けています。監査向けの説明強化だけでなく、実際に早期分岐の発火条件を変えようとしている点は評価できます。

一方で、今回の文言は「構造差が有効になる条件」を `relevant-test dependency witness` という特定の根拠型へ寄せており、failed-approaches.md が禁じている「特定の観測境界への還元」「証拠種類の事前固定」にかなり近いです。さらに、proposal 文面自体に具体 iter 番号が入っており、汎化性ルールにも抵触しています。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）

README.md / docs/design.md / SKILL.md の範囲では、提案は「証拠なしの早期結論を減らす」という意味で semi-formal reasoning の方向には沿っています。特に SKILL.md の compare が要求する per-test tracing / counterexample obligation と、構造差だけでの即断を慎重化したい意図は整合的です。

ただし整合しているのは「証拠要求を強める」方向までで、`dependency witness` を早期 NOT_EQUIV の主要根拠型として据える点は、研究コアの強化というより compare の admissible evidence を狭める設計変更です。

## 2. Exploration Framework のカテゴリ選定
判定: 条件付きで妥当

名目上は E. 表現・フォーマット改善 ですが、実効的には compare の早期分岐条件を書き換えるので、単なる wording polish ではなく「意思決定境界の再定義」です。とはいえ、新モード追加や手順純増ではなく既存 2-3 行の置換である点から、E に置くこと自体は不自然ではありません。

ただし監査上は「E と称しているが、compare の分岐条件を実質変更している」ことを明示した方がよいです。ここを曖昧にすると、監査には刺さるが compare 影響が説明不足、という停滞が起きやすいです。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
- NOT_EQUIVALENT 側: 直接作用します。従来は structural gap だけで早期 NOT_EQUIV に行けた場面の一部が、ANALYSIS 継続へ押し戻されます。偽 NOT_EQUIV は減りうる一方、真の NOT_EQUIV でも早期結論できず手数が増えます。
- EQUIVALENT 側: 間接作用です。EQUIV の判定基準自体を変える提案ではなく、NOT_EQUIV への早期流入を減らした結果として、ANALYSIS を経て EQUIV に戻るケースが増える、という形です。
- したがって片方向にしか作用しないか: 「完全な片方向」ではないが、主作用は明らかに NOT_EQUIV 側です。EQUIV 側への改善は副次的で、逆方向悪化（真の NOT_EQUIV を取り逃がす）への明示的な緩和策はまだ弱いです。

## 4. failed-approaches.md との照合
結論: 本質的再演の懸念あり

failed-approaches.md には次が明記されています。
- 「既存の判定基準を、特定の観測境界だけに過度に還元しすぎない」
- 「結論根拠の型を単一の観測可能な witness に揃える方向の具体化も同類」

今回の proposal はまさに、早期 NOT_EQUIV の admissible evidence を `relevant-test dependency witness` に寄せています。例として import / call path / test-data reference を許していても、どれも「relevant test 依存の witness」という同一族です。したがって、表現を変えた再演に近いです。

## 5. 汎化性チェック
判定: 違反あり

指摘:
- proposal 冒頭に `iter-33/34/38` という具体的 numeric ID が入っています。ユーザー指定ルール上、これは実装者のルール違反として指摘対象です。
- リポジトリ名・テスト名・実コード断片の持ち込みは見当たりません。
- ただし `import/call path/test-data reference` という witness 例示は、言語非依存ではあるものの「テスト経路へマップしやすい差分」を優先する暗黙の前提が強く、非テスト資産や設定駆動差分の広い扱いを弱める恐れがあります。

## 6. 期待される推論品質向上
期待できる改善はあります。
- 構造差だけでの早期断定を減らし、ANALYSIS へ押し戻す条件が明確になる
- 「ファイル差があるから違うはず」という粗い NOT_EQUIV を減らせる
- compare の出力において、UNVERIFIED な impact を NOT_EQUIV 根拠として使う誤りを抑えやすい

ただしその改善は、「早期 NOT_EQUIV の根拠を狭める」ことで得るタイプなので、真の structural mismatch を早く拾う力まで一緒に弱める回帰リスクがあります。

## 停滞診断（必須）
- 懸念 1 点: 監査 rubric には刺さる説明（“根拠を伴うときだけ発火”）が十分ですが、compare の実行で許容される根拠型を狭めることの副作用説明が薄く、実運用では「早期 NOT_EQUIV が減る」以外の意思決定差がやや単調です。

- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: YES
  - 原因文言: `relevant-test dependency witness` / `import/call path/test-data reference`

## compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - structural gap を見つけただけでは NOT_EQUIV を即断しにくくなり、ANALYSIS 継続が増える。
  - その結果、ANSWER が `NO not equivalent` から `YES equivalent` または低信頼結論へ変わるケースが観測可能に増える。

- 1) Decision-point delta:
  - Before/After が IF/THEN 2 行になっているか: YES
  - ただし compare 影響が理由の言い換えだけか: NO。条件と行動が実際に変わっている。
  - Trigger line の自己引用があるか: YES
  - コメント: この点は proposal の中で最も良い部分です。発火行の自己引用まで含めており、実装ズレの危険は低いです。

- 2) Failure-mode target:
  - 主対象: 偽 NOT_EQUIV
  - 副作用リスク: 真の NOT_EQUIV でも早期断定が抑制され、十分な ANALYSIS を回し切れない場合に偽 EQUIV へ流れる可能性
  - メカニズム: structural gap 単独を不十分として扱い、impact witness がない場合は継続探索へ回すため

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か?: YES
  - `impact witness` を要求しているか?: YES
  - ただし witness の型を実質的に relevant-test dependency family へ寄せているため、ここが compare 停滞の新たなボトルネックになりうる。

- 3) Non-goal:
  - 読解順序の固定はしない
  - 新しい独立ゲートは増やさない
  - ただし「早期 NOT_EQUIV の admissible evidence をどの family に限るか」は変えない/狭めすぎない、という境界条件を明記すべき

- 追加チェック: Discriminative probe:
  - 提案内の抽象ケース自体は有効です。片側に追加ファイルがあるが relevant tests は触れない場合、Before は偽 NOT_EQUIV に倒れやすく、After は ANALYSIS に戻して EQUIV を回復できる、という差は具体です。
  - ただし probe が救うのは主に「余分な追加物」のケースで、逆向きに「structural gap 自体が十分強い非同値証拠」なケースの守りは弱いです。

- 追加チェック（支払い）:
  - 「支払い（必須ゲート総量不変）」の A/B 対応付けが明示されているか: YES
  - `置換のみ` と書かれており、純増ではないことは明記できています。

## 監査コメント
良い点は、compare 停滞の典型である「監査向け説明だけ増えて実行時分岐が変わらない」提案ではなく、早期 NOT_EQUIV の発火条件そのものを書き換えている点です。Decision-point delta と Trigger line も揃っており、proposal としての体裁はかなり良いです。

ただし最大の問題は、早期 NOT_EQUIV の根拠を `relevant-test dependency witness` へ揃える方向が、failed-approaches.md の「単一 witness への還元」そのものに近いことです。これは compare の誤爆を減らす代わりに、他の有効な structural signal を捨てやすく、結果として compare 全体を弱める懸念があります。加えて iter 番号の明記は汎化性ルール違反です。

## 修正指示（2-3点）
1. `iter-33/34/38` のような具体 ID を proposal から削除してください。過去失敗は「結論直前メタ判断の追加」「探索経路の半固定化」のような一般化表現だけで足ります。
2. `relevant-test dependency witness` を唯一の admissible 根拠族として置かないでください。置換するなら、「test outcome への具体的影響を示す観測可能根拠を 1 つ」と広げ、import/call path/test-data に閉じない書き方へ差し替えてください。
3. その広げた文言でも MUST 総量を増やさないよう、現在の early-exit 行の置換に留めることを明示してください。追加行ではなく既存 2-3 行の統合置換で十分です。

承認: NO（理由: failed-approaches.md の「結論根拠を単一 witness 型へ還元しすぎる失敗」の本質的再演に近く、さらに proposal 文面に具体 numeric ID が含まれるため）
