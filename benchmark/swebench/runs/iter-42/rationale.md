# Iteration 42 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A
- 失敗ケース: N/A
- 失敗原因の分析: compare で意味差分を見つけた後も広域の structural/high-level analysis を続けやすく、同一の relevant test を両変更で先に追う分岐が後段化していたため、差分の test-level impact 確認が遅れる停滞点があった。

## 改善仮説

意味差分を観測した直後の既定動作を、広域比較の継続ではなく shared relevant test の paired trace に置き換えると、同一テストで結果が分かれるかを早く確定でき、偽 EQUIV を減らしつつ真の NOT EQUIVALENT でも具体的反例に早く到達しやすくなる。

## 変更内容

- compare の STRUCTURAL TRIAGE を「早期に行うが、最初の targeted test trace より必ず先でなくてよい」という位置づけに置換した。
- compare の certificate template に、意味差分を観測しても divergent test outcome が未確立なら、広域比較を止めて shared relevant test を両変更で先に trace する trigger line を追加した。
- compare checklist の既存の semantic-difference 行を、上記 trigger を high-level comparison や equivalence claim より先に使う指示へ置換した。
- Trigger line (final): "When a semantic difference is observed before a divergent test outcome is established, pause broad comparison and trace one shared relevant test through that differing path on both changes before resuming wider analysis."
- この Trigger line は proposal の差分プレビューにある planned trigger line と一致しており、意図した一般化の範囲でも同等である。

## 期待効果

意味差分の発見後に paired per-test tracing を最優先にすることで、再収束説明や広域比較だけで同等と見なす誤りを減らし、差分が実際に既存テスト結果を変えるかどうかの判定を早められると期待する。これは新しい必須ゲートの純増ではなく、既存の test tracing 要求を compare の前段の順序規則へ前倒しする変更なので、判断手順の総量増加も抑えられる。