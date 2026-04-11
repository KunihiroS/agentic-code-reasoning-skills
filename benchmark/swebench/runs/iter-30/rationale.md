# Iteration 30 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75%（15/20）
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382（EQUIV 偽陽性）、django__django-14787（NOT_EQ 偽陰性）、django__django-12663（UNKNOWN）
- 失敗原因の分析:
  - 15368, 13821, 15382: compare モードで Claim C[N].1/2 のトレースを経ているにもかかわらず、`Comparison:` の判定がコードレベルの semantic difference に引きずられ DIFFERENT と結論するパターン。テストが実際に観測できるポイントまで差異が伝播するかどうかを確認せず、コード差分をそのまま outcome の差分として扱うショートカットが発生している。
  - 14787: NOT_EQ ケースで EQUIVALENT と誤判定（ターン数 28 と多く、探索過多による方向転換が疑われる）。
  - 12663: ターン上限に達して UNKNOWN（探索コスト上の問題）。

## 改善仮説

compare テンプレートの `Comparison:` 行の直前に、**SAME / DIFFERENT どちらの結論にも等しく適用される比較基準点の明示**を 1 行追加する。

現状の `Comparison:` 行は「何に基づいて判定するか」が明示されていないため、AI は Claim C[N].1/2 で既にトレースした PASS/FAIL 結果を参照せず、コードレベルの差分を直接 outcome に読み替えるショートカットを踏みやすい。`Comparison:` 直前に「テストが最初に観測できるポイント（returned value / raised exception / mutated state / assertion input）で判断せよ」という基準点を示すことで、AI が Claim の PASS/FAIL に立ち戻って判定するよう焦点を絞る。

この変更は：
- 新たな証明義務や条件分岐を導入しない
- SAME を記入する局面でも DIFFERENT を記入する局面でも等しく適用される（非対称な発火条件を持たない）
- 既に Claim C[N].1/2 でトレース済みの情報への参照を促すだけで、追加の探索ステップを要求しない

## 変更内容

SKILL.md の `## Compare` → `### Certificate template` → `ANALYSIS OF TEST BEHAVIOR` 内、2 か所の `Comparison: SAME / DIFFERENT outcome` 行の直前に括弧付きコメント 3 行を追加した。

- **変更 1**（fail-to-pass tests ブロック）: `Claim C[N].2` 行の直後、`Comparison:` 行の直前に追加
- **変更 2**（pass-to-pass tests ブロック）: `Claim C[N].2` 行の直後、`Comparison:` 行の直前に追加

追加行数: 各 3 行 × 2 箇所 = 合計 6 行。削除なし。

## 期待効果

- **EQUIV 正答率（現在 7/10 = 70%）→ 8-9/10（80-90%）**: 15368, 13821, 15382 の失敗パターン（コード差分 → Comparison: DIFFERENT のショートカット）を、基準点明示によって抑制できると予測する。
- **NOT_EQ 正答率（現在 8/10 = 80%）→ 変化なし**: 真の NOT_EQ ケースでは Claim C[N].1/2 が既に FAIL/PASS の divergence を示しており、基準点明示はその判断を変えない。BL-14（DIFFERENT 主張時のみ backward verify を要求）とは構造が異なり、非対称な追加義務を課さない。
- **総合予測**: 15/20（75%）→ 16-17/20（80-85%）
