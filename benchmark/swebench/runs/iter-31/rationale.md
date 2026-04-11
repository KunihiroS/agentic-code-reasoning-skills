# Iteration 31 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70%（14/20）
- 失敗ケース: 15368, 13821（EQUIV 偽陽性）、11433（NOT_EQ 偽陰性）、15382, 14122, 12663（UNKNOWN）
- 失敗原因の分析: EQUIV 偽陽性（15368, 13821）の主因は、エージェントが Change B のトレース中にコードパス上の差分を発見した時点でトレースを打ち切り、「コード差分 → テスト結果が異なる」という推論ジャンプを行っていること。現行の Guardrail 2 はコードパスのトレースを要求するが、トレースの終着点（テストの PASS/FAIL を実際に決定するアサーションまたは条件）を明示していないため、コード差分の発見をトレース完了とみなすショートカットを防げていない。

## 改善仮説

Guardrail 2 のトレース要件に「アサーションまたは PASS/FAIL を直接決定する条件に到達するまで」という終着点を明示することで、コード差分発見後もアサーション到達まで追跡を継続させ、コード差分発見 → テスト結果相違の推論ジャンプを防ぐことができる。

## 変更内容

`## Guardrails` セクション内の Guardrail 2 の文言を以下のように修正した。

**変更前:**
```
2. **Do not claim test outcomes without tracing.** Trace each test through the relevant code path before asserting PASS or FAIL.
```

**変更後:**
```
2. **Do not claim test outcomes without tracing.** Trace each test through the relevant code path, reaching the assertion or condition that directly determines PASS or FAIL, before asserting either outcome.
```

変更点: `, reaching the assertion or condition that directly determines PASS or FAIL,` というフレーズを挿入し、末尾の `PASS or FAIL` を `either outcome` に変更（重複を解消）。変更行数は1行、追加語数は約 +8語。

## 期待効果

- **EQUIV（15368, 13821）**: アサーション到達まで追跡が完了しないことが明示されるため、コード差分発見後の推論ジャンプが抑制される。7/10 → 8〜9/10（+1〜2件）の改善を予測。
- **NOT_EQ（11433）**: 要件は PASS・FAIL 両方向に等しく適用されるため、立証責任を非対称に引き上げない。中立〜+1件の改善を予測。
- **総合**: 14/20（70%）→ 15〜17/20（75〜85%）を予測。
