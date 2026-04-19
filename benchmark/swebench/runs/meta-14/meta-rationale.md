# meta-14 rationale — template improvements

## 停滞の診断（どのテンプレートのどの部分が問題か）

1) propose-normal.txt が「STRUCTURAL TRIAGE / 早期 NOT_EQUIV」周りを過剰にタブー化しており、compare 改善で最もレバレッジが大きい意思決定ポイントに触れにくい。
   - 該当箇所: propose-normal.txt の「直近の却下履歴」直後の注意書き、および「禁止パターン」内の
     「構造差→NOT_EQUIV を … に狭める → 全て却下済み」。
   - 結果: “早期 NOT_EQUIV の誤り（偽 NOT_EQUIV）”を減らすための改善が、
     「過去却下の再演」と誤判定されやすく、提案空間が狭まる。

2) propose-normal.txt は「必須ゲート純増禁止」を掲げる一方、proposal 出力に「支払い（payment）」を明示させる強いフォーマット要求がなく、
   変更が (a) 必須ゲートの純増リスクを曖昧にしたまま通る、または (b) 支払い先を見つけられず比較に効く変更を避ける、
   のどちらにも転びやすい。
   - 該当箇所: propose-normal.txt の提案ルール（必須ゲート純増禁止）

3) discuss.txt は compare 影響の実効性チェックを持つが、STRUCTURAL TRIAGE/早期結論に触れる提案について
   「ファイル差があるだけで NOT_EQUIV に寄りやすい」タイプの停滞（偽 NOT_EQUIV）を明示的にブロックする観点が弱い。
   - 該当箇所: discuss.txt の「compare 影響の実効性チェック」

4) implement.txt は Trigger line / Decision-point delta の整合を求めているが、
   Trigger line が“分岐を発火させる場所”ではなく注意書き的に末尾へ追記される形に落ちると、
   実際の意思決定（IF/THEN）が変わらず compare が動かないまま audit だけ改善しがち。
   - 該当箇所: implement.txt の「仕上げチェック」

上記 1)〜4) が合成され、監査スコアは伸びても compare の意思決定が実質変化しない／または偽 NOT_EQUIV が増える方向にブレ、
スコアが停滞・上下しやすい構造になっていた。


## 変更の仮説（なぜこの変更で改善が期待できるか）

仮説: compare の停滞の主因は「STRUCTURAL TRIAGE 等の早期 NOT_EQUIV が、具体的な PASS/FAIL（assertion boundary）への接続なしに発火しやすい」ことによる
偽 NOT_EQUIV であり、ここを改善する提案がテンプレート上の“禁止の誤解”で出にくかった。

そのため、
- propose-normal 側で「過去却下の本質（観測境界への写像＝探索経路の半固定）」と
  「偽 NOT_EQUIV を減らすための根拠明確化（impact witness / assertion boundary）」を明確に区別して、
  高レバレッジな提案を許容する。
- discuss 側で、STRUCTURAL TRIAGE/早期結論に触れる提案に対し「impact witness を要求できているか」を YES/NO で強制チェックし、
  “ファイル差だけで NOT_EQUIV” 型の停滞をゲートで止める。
- propose-normal で「必須ゲート純増禁止」を運用可能にするため、proposal で payment 表記をフォーマットとして要求し、
  “必須追加したのに支払いが曖昧”や“支払い先を探せず比較に効く変更を避ける”を減らす。
- implement 側で Trigger line の配置品質（分岐発火点に置く）を明示し、compare に効く形での実装ズレを減らす。

これにより、監査 PASS を維持しながら、compare の誤判定（特に偽 NOT_EQUIV）を減らす方向の変更が提案・実装されやすくなり、
compare スコアの底上げが期待できる。


## 変更したファイルと変更内容の要約

1) prompts/propose-normal.txt
   - 「構造差/早期 NOT_EQUIV」注意書きを、却下済みの方向（観測境界への写像で狭める）と、
     許容したい別方向（偽 NOT_EQUIV を減らすための assertion boundary / impact witness による根拠具体化）に明確に分離。
   - 「必須ゲート純増禁止」の運用強化として、proposal.md 内に payment 明記フォーマットを追加。
   - 禁止パターンの文言を精密化し、境界固定と根拠明確化を区別。

2) prompts/discuss.txt
   - compare 影響の実効性チェックに「2.5) STRUCTURAL TRIAGE / 早期結論」チェックを追加。
   - 早期 NOT_EQUIV の根拠が“ファイル差だけ”に退化していないか、impact witness（assertion boundary の目撃）を要求できているかを YES/NO で強制。

3) prompts/implement.txt
   - 仕上げチェックを強化し、Trigger line が“分岐の発火点”に置かれているか、
     Before/After が理由言い換えに落ちていないかを明示。
