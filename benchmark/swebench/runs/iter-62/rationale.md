# Iteration 62 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: django__django-15368, django__django-15382, django__django-14787
- 失敗原因の分析: 15368・15382 はコード差異を発見後「テスト結果に影響するか」を十分に問わずに EQUIV → NOT_EQUIVALENT / UNKNOWN へジャンプ（浅い推論）。14787 は反例の見つけ損ねにより NOT_EQUIVALENT → EQUIVALENT の誤判定。

## 改善仮説

compare モードの Certificate template 実行前に「各変更による挙動差異はテストの PASS/FAIL 結果への影響を問う」というフレーミング指示を 1 行追加することで、エージェントがコード差異発見後に「テスト結果に影響するか」を自然に問いかけながら分析を進め、コード差異 → テスト不合格への浅い推論ジャンプ（EQUIV 偽陰性パターン）が抑制される。

## 変更内容

`## Compare` → `### Certificate template` の第 1 instruction 行（"Complete every section…"）の直後に以下の 1 行を追加した。

> Throughout the analysis, ask: does the changed behavior cause each relevant test to produce a different PASS/FAIL result?

追加 1 行・変更 0 行・削除 0 行。他セクション（localize, explain, audit-improve, Core Method, Guardrails）は無変更。

## 期待効果

- **15368 / 15382（EQUIV 誤答）**: テンプレート冒頭の framing により「PASS/FAIL の差異があるか？」という問いが最初に植え付けられ、コード差異発見後も自然にテスト結果への影響を評価するステップを踏むようになる。EQUIV 正答率 7/10 → 8〜9/10 を期待。
- **14787（NOT_EQ 誤答）**: 「PASS/FAIL 差異を探せ」というフレームが反例発見を若干促進する可能性がある。
- **NOT_EQ 既存正答（10/10）**: 1 行の soft framing であり、実行義務・記録フィールド追加なし。リグレッションリスクは極めて低い。
