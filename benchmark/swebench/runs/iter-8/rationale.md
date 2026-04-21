# Iteration 8 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（このタスクで参照可能なファイルには未記載）
- 失敗ケース: N/A（このタスクで参照可能なファイルには未記載）
- 失敗原因の分析: 比較時に局所的な semantic difference を見つけた直後、その差分自体から test impact を語りやすく、差分を最初に解釈する下流コードへの読解優先順位が未指定だったため、偽 NOT_EQUIV と偽 EQUIV の両方を招きうる停滞点があると分析した。

## 改善仮説

局所差分を見つけた瞬間に、その差分を最初に消費・正規化・分岐化する下流コードを先に読むよう compare の取得順序を具体化すると、局所差分を即座に結論へ短絡させにくくなり、test outcome に接続する最も判別的な証拠へ早く到達できる。

## 変更内容

- Compare checklist の「差分発見後に relevant test を trace する」指示を、まず immediate downstream interpreter を読む指示へ置換した。
- Guardrail #5 の「下流で既に処理されていないか verify する」という一般指示を、semantic difference 発見時に first downstream consumer/interpreter を先に読む具体指示へ置換した。
- 追加ではなく置換でそろえ、結論前の必須判定手順の総量を増やさずに、差分発見後の次の一手だけを変えた。

## 期待効果

局所差分が下流で同じ predicate や同じ assert-relevant state に正規化される場合の偽 NOT_EQUIV と、逆に下流で別分岐や別例外へ変換される場合の偽 EQUIV を減らし、EQUIV / NOT_EQUIV の判別精度を改善できると期待する。

Trigger line (final): "When a semantic difference is first found, read the immediate downstream code that interprets that differing value/exception/state before classifying its test impact."

この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、差分発見時の分岐を compare checklist の該当位置で実際に発火させる。