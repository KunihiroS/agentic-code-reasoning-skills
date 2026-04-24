# Iteration 48 — 変更理由

## 前イテレーションの分析

- 前回スコア: proposal では未記載
- 失敗ケース: proposal では固有ケースを対象化しない
- 失敗原因の分析: 探索ログ内で「次に読む理由」と「情報利得」を近接した別欄に二重記入させており、optional 欄が省かれると、追加探索・保留・結論へ進む判断が claim/verdict の変化可能性に結びつきにくい。

## 改善仮説

optional な情報利得欄を既存の required 欄へ統合すれば、新しい必須ゲートを増やさずに、次アクションの判定基準を「どの不確実性を解き、どの claim/verdict を変えうるか」へ寄せられる。これにより、探索継続と結論移行の分岐が短くなり、過度な保留や早期結論を減らせる。

Trigger line (final): "NEXT ACTION RATIONALE: [what uncertainty this action resolves and what claim/verdict could change]"

この Trigger line は proposal の差分プレビューにあった planned line と一致しており、Decision-point delta の分岐を発火させる Step 3 の次アクション欄に配置した。

## 変更内容

Step 3 の読解後テンプレートで、`NEXT ACTION RATIONALE: [why the next file or step is justified]` と `OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]` の 2 行を、`NEXT ACTION RATIONALE: [what uncertainty this action resolves and what claim/verdict could change]` の 1 行へ置換した。

## 期待効果

次に読む対象が複数ある場合や現時点で結論へ進むか迷う場合に、単なる「読む理由」ではなく、解消する不確実性と変わりうる claim/verdict を同じ required 欄で明示するため、判定に効く追加探索を選びやすくなる。必須要素の総量は増やさず optional 欄を削除しているため、認知負荷の増加を避けながら compare の意思決定点だけを変える効果が期待できる。
