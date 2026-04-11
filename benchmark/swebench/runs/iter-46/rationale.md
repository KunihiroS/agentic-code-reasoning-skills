# Iteration 46 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70%（14/20）
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-12262, django__django-14122
- 失敗原因の分析:
  - EQUIV 偽陰性（15368, 13821, 15382）: 変更関数の返り値（中間値）を `Observed` に記録した後、downstream の wrapper/handler を読まずに `Comparison: DIFFERENT` と判定した。実際には差異が downstream で吸収され、テストが観測する時点では同一値になっていた。
  - NOT_EQ UNKNOWN（14787, 12262, 14122）: ターン上限に達して判定不能になったケース。今回の変更との直接的な関連は低い。

## 改善仮説

`compare` モードの Guardrail に「`Observed under Change A/B` に書いた値が変更関数の直接出力（中間値）であれば、その値が渡される次の downstream consumer を 1 hop 読んでから `Comparison:` を書く」という軽量な読解規則を追加することで、推論連鎖が途中で止まるケース（EQUIV 偽陰性）を減らせる。

## 変更内容

`## Guardrails` → `### From the paper's error analysis` 内の Guardrail 5 と 6 の間に、新規 Guardrail 5a を追加した。

```
5a. **In `compare` mode: if `Observed` is an intermediate value, read one downstream consumer before comparing.** If the value written in `Observed under Change A` or `Observed under Change B` is taken directly from the changed function's output and has not yet reached the code the test observes, read the next function or caller that receives that value before writing `Comparison:`. One hop is sufficient — do not require full end-to-end tracing. This prevents stopping at intermediate differences that cancel out downstream.
```

既存の Guardrail・テンプレートブロック（ANALYSIS OF TEST BEHAVIOR 等）への変更なし。追加のみ（3行）。

## 期待効果

- **EQUIV 正答率の改善（15368, 13821, 15382）**: Observed に中間値が書かれた場合に 1 hop 先を読む行動が促されることで、差異が downstream で収束するケースを正しく EQUIV と判定できる見込み。
- **NOT_EQ 回帰リスクの抑制**: 真の NOT_EQ では downstream を 1 hop 読んでも差異が維持されるため、`Comparison: DIFFERENT` の判断は変わらない。「1 hop」という量の限定により full downstream trace 義務とならず、証明コストを大幅に増やさない。
- `Observed` フィールドの記述要件は変更しないため、BL-5/11/13/16 が指摘する観測フレームの過剰規定を踏まない。
