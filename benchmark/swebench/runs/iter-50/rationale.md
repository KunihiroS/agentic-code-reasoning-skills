# Iteration 50 — 変更理由

## 前イテレーションの分析

- 前回スコア: 提案内では未指定
- 失敗ケース: 固有ケースには依存しない一般的な比較推論の停滞
- 失敗原因の分析: 次に読む情報を、単なる仮説 confidence ではなく、未解決の EQUIV/NOT_EQUIV claim を confirm/refute できる証拠として明示できないまま探索が進むと、無関係な読解や早すぎる結論に流れやすい。

## 改善仮説

事前 confidence ラベルよりも、次の読解がどの未解決 verdict claim を反転または確定しうるかを先に書かせる方が、EQUIV と NOT_EQUIV のどちらにも片寄らず、compare に効く探索優先順位を改善できる。

Trigger line (final): "DISCRIMINATIVE QUERY: [which unsettled EQUIV/NOT_EQUIV claim this read can confirm vs refute]"

この Trigger line は提案の差分プレビューにあった Trigger line と一致しており、Step 3 のファイル読解前に分岐を発火させる位置へ入っている。

## 変更内容

SKILL.md の Step 3 で、読解前テンプレートの `CONFIDENCE: high / medium / low` を上記 Trigger line に置換した。あわせて、読解後テンプレートでは optional な情報利得行を削除し、`NEXT ACTION RATIONALE: [why this query is the next highest-information read]` に置換して、必須ゲートの総量を増やさずに探索理由を verdict-discriminative な query に結びつけた。

Decision-point delta:
- Before: IF a plausible hypothesis and supporting evidence can be stated THEN open the next file because confidence is labeled high/medium/low.
- After: IF the next read can name an unsettled EQUIV/NOT_EQUIV claim and evidence that would confirm vs refute it THEN open that file; otherwise choose a different query or mark the claim UNVERIFIED/LOW because the expected information gain is not verdict-discriminative.

## 期待効果

近い定義や見た目上 plausible な場所を confidence 付きで読み続けるのではなく、反対 outcome を検出できる読解を優先しやすくなる。これにより、無関係な差分に引かれる誤った NOT_EQUIV と、未確認の差を見落とす誤った EQUIV の両方を減らすことが期待できる。
