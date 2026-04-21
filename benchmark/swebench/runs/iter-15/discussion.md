# iter-15 discussion

## 総評
提案の狙い自体は理解できる。fail-to-pass test の assertion/check と、その asserted value を直に作る helper を最初の探索アンカーにする、という発想は「観測可能な差」に早く接続するための探索優先順位づけであり、Exploration Framework ではカテゴリ B（情報の取得方法の改善）に素直に入る。

ただし、今回の差分プレビューはその優先順位づけを D2 の「relevant tests の特定方法」へ入れており、ここが compare の実行時挙動を片方向に崩す懸念が強い。fail-to-pass 起点の読み順改善と、pass-to-pass を含む relevant tests の発見規則は分けるべきで、現状の書き方だと compare に効く変更ではなく、compare の探索範囲を狭める変更として実装されうる。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。
この提案は「test oracle / assertion から観測差へ接続する」「差分そのものより判定境界を先に押さえる」という一般的な静的推論原則の範囲で説明可能で、特定概念への強い依拠は見えない。

## 2. Exploration Framework のカテゴリ選定
判定: 適切。
理由:
- 提案は新しい結論ルールや新しい証拠ゲートを足すものではなく、「何を先に読むか」の優先順位を変えるもの。
- したがって A（順序変更）にも少し接するが、主作用は「探索アンカーの選び方」なので B が主カテゴリでよい。
- ただし、実装位置を誤ると B ではなく「relevant tests の定義変更」になってしまう。現プレビューはその危険がある。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
- NOT_EQUIVALENT 側には効きうる。assertion boundary を先に押さえることで、単なる file diff ではなく「どの assert/check が割れるか」に接続しやすくなるため、偽 NOT_EQUIV と偽 EQUIV の両方を減らす余地はある。
- ただし現プレビューのまま D2 を置換すると、pass-to-pass の relevant tests 発見が弱まり、既存 passing path 上の回帰差分を見逃しやすくなる。これは偽 EQUIV を増やす片方向リスク。
- つまり、狙いは両方向改善だが、書かれている差分プレビューは fail-to-pass 側にだけ最適化され、逆方向（pass-to-pass 起点の NOT_EQUIV 発見）を悪化させうる。

## 4. failed-approaches.md との照合
本質的再演か: ぎりぎり回避しているが、現プレビューには再演の芽がある。

- 原則 1（再収束の既定化）: 今回は再収束そのものを規範化していないので直接の再演ではない。
- 原則 2（未確定を保留へ倒す既定動作）: その種の fallback は増えていない。
- 原則 3（新しい抽象ラベルで強くゲート）: 新ラベルは導入していない。

ただし、探索開始点を fail-to-pass assertion/helper に強く固定すると、「比較対象の全景を必要に応じて広げる」より前に、ある種の証拠様式へ探索を半固定する危険はある。これは failed-approaches.md の三原則そのものではないが、compare 停滞の温床にはなりうる。

## 5. 汎化性チェック
判定: おおむね問題なし。
- 具体的なベンチマーク ID、特定リポジトリ名、特定テスト名、実コード断片は含まれていない。
- SKILL.md 自身の文言引用は Objective.md 上も減点対象外。
- ドメイン依存性も強くない。assertion/check、helper、asserted value は多言語・多フレームワークで通る。

軽微な注意:
- 「nearest helper」が常に明確とは限らず、DSL・設定駆動・declarative framework・macro 展開系では helper ではなく mapping/config/boundary object が観測値を作ることがある。ここを helper に寄せすぎると暗黙に命令的コードパターンを想定する。

## 6. 全体の推論品質への期待効果
期待できる改善はある。
- 差分先読みで「差分がある/ない」に引っ張られるより、assertion boundary 起点で「何が観測されるか」を先に固定する方が、relevance の高い trace に入りやすい。
- とくに subtle difference dismissal を減らし、証拠の粒度を assertion outcome に近づける効果は見込める。
- ただし、その効果は「relevant tests の発見」を壊さずに、fail-to-pass 特定“後”の初動読みに限定した場合に限る。

## 停滞診断（必須）
- 懸念 1 点: 提案は監査 rubric には刺さりやすいが、差分プレビューの実装位置が D2 だと compare の意思決定改善ではなく relevant tests 発見の狭窄になり、観測可能な runtime outcome の差が「良い方向」に安定しない。

- 探索経路の半固定: YES
  - 原因文言: "For each fail-to-pass test, read the assertion site and the nearest helper ... before tracing deeper implementation differences"
  - 評価: 全経路固定ではないが、初動を必須で固定している。
- 必須ゲート増: NO
  - 理由: payment を明示しており、総量は増やさない意図がある。
- 証拠種類の事前固定: YES
  - 原因文言: assertion/check と nearest helper を優先証拠として先に固定している。
  - 評価: 軽度。証拠種そのものを唯一化してはいないが、初動証拠の型を事前固定している。

## compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - 観測可能に変わる点はある。fail-to-pass が分かったケースで、最初に開く対象が changed file/symbol から assertion/helper へ変わるため、追加探索要求の出し方と、NOT_EQUIV を出すときの根拠の粒度が変わる。
  - ただし現プレビューどおり D2 に入ると、pass-to-pass を拾えず、EQUIV に倒れやすくなるという別の観測可能差も出る。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Before/After は分岐として変わっているか？ YES
  - Trigger line（発火する文言の自己引用）が含まれているか？ YES
  - ただし最大の問題は、分岐を差し込む位置が悪いこと。D2 の test-identification 規則を置換すると、読み順変更ではなく探索対象の発見規則変更になる。

- 2) Failure-mode target:
  - 主対象: 両方
  - 狙う誤判定メカニズム: changed-code 先読みで relevance の低い差分へ引っ張られ、偽 NOT_EQUIV（差分を過大視）または偽 EQUIV（下流吸収を雑に仮定）を起こすこと。
  - ただし現プレビューのままでは副作用として偽 EQUIV を増やしうる。理由は pass-to-pass discovery の弱化。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO
  - impact witness を要求しているか？ N/A

- 3) Non-goal:
  - 変えない境界は「relevant tests の集合定義」「STRUCTURAL TRIAGE の早期結論条件」「証拠の許容型の多様性」。
  - 変えるのは fail-to-pass test が得られた後の“最初の読みに入る優先順位”だけに留めるべき。

- Discriminative probe:
  - 抽象ケース: 2 変更が同じ changed function を触るが、実際の分岐は test assertion の直前で config normalization を挟む。変更前ルールでは changed files を先に広く読んで差分を重く見てしまい、偽 NOT_EQUIV が起きうる。
  - 変更後ルールを「fail-to-pass 特定後の初動読み」に限定すれば、assertion と normalization boundary を先に見て、観測差が吸収されるかを確認してから deeper trace に入れるため、誤判定を減らせる。
  - これは新しい必須ゲート追加ではなく、既存の初動優先順位の置換として説明できている。

- 追加チェック（停滞対策）:
  - 支払い（必須ゲート総量不変）の A/B 対応付けが明示されているか？ YES
  - ただし remove 対象の "Identify changed files for both sides" は STRUCTURAL TRIAGE と役割重複がある一方、D2 側を触ると別の機能を壊す。payment の場所選びは再設計が必要。

## 最大ブロッカー
D2 の relevant-tests identification を置換してしまっている点。これにより、fail-to-pass 後の読み順改善という提案意図を超えて、pass-to-pass を含む compare の探索範囲そのものを狭め、偽 EQUIV を増やす片方向最適化になっている。

## 修正指示（2〜3点）
1. 置換箇所を D2 から外し、「fail-to-pass test が特定できた後の初動読み順」を述べる compare checklist か ANALYSIS 導入文へ移すこと。
   - 追加するなら、D2 の relevant-tests discovery 規則は維持する。
2. payment は D2 の discovery 文ではなく、重複している checklist 側の changed-files 明示を optional 化/統合して支払うこと。
   - 例: "Identify changed files for both sides" を STRUCTURAL TRIAGE に統合し、別立ての checklist 項目から外す。
3. "nearest helper" を "nearest value-producing helper/boundary (including config/mapping/adapter)" のように少し広げ、命令的 helper パターンへの暗黙バイアスを下げること。

## 承認
承認: NO（理由: fail-to-pass 起点の読み順改善を、D2 の relevant tests 発見規則の置換として実装しており、pass-to-pass 側を弱める片方向最適化が明白）
