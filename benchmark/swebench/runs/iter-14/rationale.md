# Iteration 14 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業では参照対象外）
- 失敗ケース: N/A（この作業では参照対象外）
- 失敗原因の分析: compare の per-test analysis が各 change の前向き個別 trace を既定にしており、同じ test outcome を説明できる複数 path がある場合に、verdict を直接左右する判定ピボットよりも下流の再収束や上流の構造差を先に見てしまう余地があった。

## 改善仮説

relevant test ごとに、まず verdict-setting assertion/check とそれを反転させうる最短の upstream decision を両 change で並べる順序へ置換すると、EQUIV と NOT EQUIV の判定が test verdict を分ける条件により直接結びつき、前向き全追跡由来の偽 EQUIV / 偽 NOT_EQUIV を減らせる。

## 変更内容

ANALYSIS OF TEST BEHAVIOR の relevant test テンプレートを、前向き trace の because 節から、Trigger line・Pivot・pivot resolves to [value/branch] 形式へ置換した。あわせて checklist の "Trace each test through both changes separately before comparing" を、assertion/check 起点で backtrace し未解決時のみ下流へ展開する指示へ置換した。追加の必須ゲートは増やさず、既存の per-test tracing の開始点だけを差し替えた。

Trigger line (final): "For each relevant test, first anchor the verdict-setting assertion/check and backtrace the nearest upstream decision that could make Change A and Change B disagree."

この Trigger line は proposal の差分プレビューにある planned trigger line と一致しており、意図した一般化の範囲でも同等である。

## 期待効果

relevant test ごとの比較が、changed path の網羅量ではなく test verdict を分ける判定ピボットの識別に先に集中するため、同じ outcome に見えるケースでは EQUIV の根拠を、分岐するケースでは NOT EQUIV の根拠を、より少ない寄り道で確定しやすくなる。研究コアである番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持される。