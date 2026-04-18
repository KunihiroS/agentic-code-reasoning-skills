# Iteration 17 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（このタスクではスコア/失敗ケース情報が提供されていない）
- 失敗ケース: 不明（同上）
- 失敗原因の分析: 不明（同上）

## 改善仮説

`compare` における Step 5（反証）の優先順位が「結論反転レバレッジ」基準に寄りすぎると、A/B の差分を見つけても“どの入力・どの assertion で分岐するか”への接続が弱くなり、偽 EQUIV（影響を過小評価）と偽 NOT_EQUIV（反例なし差分で過大評価）の両方が起きうる。そこで、反証の第一候補を「最小の振る舞い分岐（divergence candidate）」へ寄せてから潰すことで、差分→反例（または反例不在）の判定をより判別的にする。

## 変更内容

- Step 5 の「最初に反証する対象の選び方」を、`compare` に限って divergence candidate 優先へ差し替えた。
- `compare` 以外では従来どおり、否定すると結論が反転する主張（レバレッジ最大）を優先する。

Trigger line (final): "- In `compare`, prioritize refuting the top-ranked divergence candidate first (a minimal A↔B behavioral branch on a relevant call path; list 1–3 candidates)."
上の Trigger line は proposal の差分プレビューにある After の 1 行目と同文であり、意図した一般化として一致している。

## 期待効果

- 偽 EQUIV の抑制: “差分はあるが影響なし”を主張する前に、分岐する assertion/入力に結びつく最小分岐候補を優先的に反証し、影響の取りこぼしを減らす。
- 偽 NOT_EQUIV の抑制: 反例（分岐する assertion/入力）を提示できない差分だけで早期に NOT_EQUIV と断定しにくくする（新しい必須ゲートの純増は行わず、既存 Step 5 の優先順位付けのみを変更）。
