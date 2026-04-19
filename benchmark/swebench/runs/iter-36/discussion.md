# Iteration 36 Discussion

## 総評
提案の主眼は、compare の STRUCTURAL TRIAGE にある早期 NOT_EQUIV 分岐を「構造差がある」だけで発火させず、「その構造差が実際にテスト結果差へ接続する最小限の根拠」を要求する点にある。これは監査向けの説明強化だけでなく、compare 実行時の分岐そのものを変える提案になっており、停滞対策の要求には概ね合致している。

一方で、Exploration Framework のカテゴリ選定はややズレている。提案文はカテゴリB（情報の取得方法）として書かれているが、実際の主変更点は compare の早期結論条件を変えるもので、主分類としてはカテゴリC（比較の枠組みを変える）の方が自然。副次的に「何を確認してから結論へ進むか」を触るので B 要素もあるが、監査上は C 寄りと明記した方が機構が伝わりやすい。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md / SKILL.md の範囲で見ても、番号付き前提・仮説駆動探索・手続き間トレース・必須反証という研究コアは維持されている。今回の変更は compare モードの早期 short-circuit に対して、反証可能性と根拠密度を補強する局所修正であり、研究の本筋から外れていない。

## 2. Exploration Framework のカテゴリ選定
判定: 部分的に適切だが、主カテゴリは B ではなく C が妥当。

理由:
- 提案の核心は「どう探すか」より「どの条件で早期 NOT_EQUIV に進めるか」の変更。
- つまり探索の手順改善というより、compare の判定フレームにある early-exit 条件の再定義。
- そのため、主分類を C、補助的に B と整理すると proposal の実効差が読み取りやすい。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - これまで structural gap だけで NOT_EQUIV に早期着地していたケースの一部が、ANALYSIS 継続または EQUIV / UNVERIFIED / 低信頼へ再分岐する。
  - FORMAL CONCLUSION で、早期 NOT_EQUIV のときに impact witness の有無が観測可能な差として現れる。

- 1) Decision-point delta:
  - Before/After が IF/THEN 形式で 2 行になっているか: YES
  - Trigger line（自己引用）があるか: YES
  - 評価: 条件も行動も実際に変わっている。Before は structural gap で即 early-exit、After は impact witness を書ける場合だけ early-exit、書けなければ ANALYSIS 続行なので、理由の言い換えではない。

- 2) Failure-mode target:
  - 主対象は偽 NOT_EQUIV。
  - 機構は、構造差を見つけた瞬間の短絡を抑え、「差が assertion boundary や concrete usage にどう届くか」を確認できない限り結論を保留/追加探索に回すこと。
  - 副次的には、EQUIV 側でも「本当に差がないのか」を追加探索で確かめる機会が増えるため、片方向専用ではない。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？: YES
  - impact witness を要求しているか: YES
  - 評価: 「ファイル差がある」だけで NOT_EQUIV に退化するのを防ぐ設計になっている。

- 3) Non-goal:
  - 探索入口や読解順序を固定しないこと。
  - 特定の証拠テンプレを増設しないこと。
  - 必須ゲート総量を増やさず、既存文言の置換で支払うこと。

- Discriminative probe:
  - 片側だけ補助ファイルを触るが、そのファイルがテスト結果に接続しないケースでは、変更前は structural gap だけで偽 NOT_EQUIV へ寄りやすい。
  - 変更後は early-exit に impact witness が必要なので、接続が示せない場合は ANALYSIS に戻り、EQUIV か少なくとも UNVERIFIED/低信頼に留められる。
  - これは新ゲート純増ではなく、「early-exit 無条件許可」を「条件付き許可」へ置換する説明になっている。

- 支払い（必須ゲート総量不変）の明示:
  - YES
  - 「Complete every section...」の絶対表現を early-exit 例外付きに緩め、その代わり early-exit 時だけ impact witness を要求する、という A/B 対応が proposal 内で見えている。

## 4. EQUIVALENT 判定 / NOT_EQUIVALENT 判定への作用
NOT_EQUIVALENT 側への作用が主だが、実効差は片方向だけではない。

- NOT_EQUIVALENT への直接作用:
  - structural gap のみを根拠にした早計な NO を減らす。
  - 真の NOT_EQUIV については、テスト差へ接続する witness を簡潔に書けるケースでは従来どおり早期結論を維持できる。

- EQUIVALENT への間接作用:
  - 以前は早期 NO で潰れていたケースが ANALYSIS に進むため、EQUIV に到達できる余地が増える。
  - ただし、impact witness の定義が狭すぎると、真の NOT_EQUIV まで不必要に ANALYSIS 送りとなり、結論遅延や confidence 低下を招く可能性はある。

結論として、提案は「NO だけ厳しくして YES は据え置き」の一方向最適化ではなく、compare の分岐点を再配置する提案になっている。ただし witness 文言を狭く書きすぎると、実装時に NOT_EQUIV 側だけを過度に鈍らせる危険は残る。

## 5. failed-approaches.md との照合
本質的再演ではない。特に、過去失敗の中心だった「観測境界へ写像して探索を狭める」「読解順序の半固定」「新しい必須メタ判断の純増」とは区別できる。

ただし境界条件として、以下は明確に管理した方がよい。
- `impact witness (test/assertion boundary or concrete usage)` の括弧内列挙が、実装次第では「許される証拠型の事前固定」に見えうる。
- ここを exhaustively closed な列挙として書くと、failed-approaches.md の「証拠種類の事前固定」に寄る。
- 逆に、例示であって限定列挙ではないと明示すれば、今回の提案の本質は「証拠型の固定」ではなく「早期結論の根拠密度の底上げ」に留まる。

## 6. 汎化性チェック
判定: おおむね良好。

- proposal 内に具体的なベンチマーク ID、リポジトリ名、テスト名、実コード断片は含まれていない。
- `>200 lines` のような数値は SKILL.md の既存自己引用に紐づく一般閾値であり、ベンチマーク識別子ではない。
- 抽象ケースもコメント、デッドコード、未参照補助変更など一般的で、特定言語やドメインに閉じていない。

軽微な懸念:
- `test/assertion boundary` を中心に据えると、テスト主導の比較タスクには自然だが、assertion という語にややテスト寄りの印象はある。compare モードの定義自体が「modulo tests」なので違反ではないが、`observable outcome boundary` のようなより一般名でもよい。

## 7. 停滞診断
- 懸念点（1 点のみ）:
  - 「impact witness」という監査で説明しやすい語が前面に出ているため、実装で witness の中身が曖昧なままだと、compare の分岐を本当に変える前に“説明欄だけ厚くなる”停滞が起きうる。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO（proposal の Payment を実装どおり守る限り）
  - 証拠種類の事前固定: YES
    - 原因候補の文言: `impact witness (test/assertion boundary or concrete usage)`
    - コメント: ここを「例えば」扱いにすれば NO 寄りへ改善できる。

## 8. 推論品質の向上見込み
期待できる改善は明確。

- 早期 NOT_EQUIV の誤短絡を減らし、compare の precision を上げる方向に効く。
- 監査説明も「構造差がある」から一歩進み、「その差がなぜテスト結果差になるか」を短く接続できるため、結論の可読性が上がる。
- 変更箇所が compare セクション内の局所置換に留まるため、研究コアや他モードへの波及は限定的。

## 修正指示（最小限）
1. カテゴリ表記を「主: C、従: B」に修正する。
   - 理由: 実際の変更対象が compare の early-exit 判定だから。

2. `impact witness (test/assertion boundary or concrete usage)` を限定列挙に見えない書き方へ置換する。
   - 例: `impact witness (e.g., a concrete path to a test-observable outcome difference)`
   - これにより failed-approaches.md の「証拠種類の事前固定」リスクを下げられる。

3. After 文の early-exit 条件に、witness を書けない場合の出力先を 1 つだけ明文化する。
   - 例: `... otherwise continue ANALYSIS rather than concluding NOT EQUIVALENT from structure alone.`
   - これで compare の実行時アウトカム差がさらに観測可能になる。

## 結論
承認: YES

理由: Decision-point delta、Trigger line、impact witness、Payment、Discriminative probe の必須要件が揃っており、compare 実行時の観測可能な差が具体化されているため。最大の注意点は witness 文言が証拠型の固定に見えないようにすることだが、これは本質的な再演ではなく、最小限の wording 修正で解消可能。