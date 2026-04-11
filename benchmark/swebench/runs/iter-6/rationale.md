# Iteration 6 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: 15368, 13821, 15382
- 失敗原因の分析:
  - **15368**: テスト削除という差異を発見した後、削除されたテストは実行されないという具体的なトレースをせずに NOT_EQ と結論した。
  - **13821**: pass-to-pass テストのコードパス差異を発見した後、具体的なテスト入力をそのコードパスに通したトレースをせずに NOT_EQ と結論した。
  - **15382**: ループ内例外フローについてコード構造から推論したが、具体的な入力を通したトレースを行わずに NOT_EQ と結論した。
  - **共通パターン**: 3 件とも「コード差異を発見した後、テストを通じた具体的なトレースなしに NOT_EQ と結論する」パターンであり、問題の本質はトレースの欠如である。

## 改善仮説

Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` 内、各テストの `Comparison:` 行の直後に 1 行の自己チェック（`Trace check:`）を追加することで、AI が「実際にトレースしたか、それともコード構造から推論しただけか」をメタ認知的に確認させる。INFERRED と自己評価したケースで「trace before proceeding」という明示的な行動指示が作用し、トレースなしの NOT_EQ 結論を防ぐ。

## 変更内容

`Compare` セクションの Certificate template、`ANALYSIS OF TEST BEHAVIOR` 内の **fail-to-pass テストブロックと pass-to-pass テストブロックの両方**で、`Comparison: SAME / DIFFERENT outcome` の直後に `Trace check:` 行を追加した（既存内容は一切変更しない純粋追加）。

**追加した行（各ブロックに同一の 3 行を追加）:**
```
  Trace check: [TRACED / INFERRED] — Did I trace a concrete test input
               through the differing code path, or infer from code structure alone?
               If INFERRED, trace before proceeding.
```

変更規模: 追加 3 行 × 2 箇所 = 計 6 行、削除・変更 0 行。影響範囲は Compare モードの certificate template のみ。他のモード（localize, explain, audit-improve）、Step 3〜5.5、Guardrails への影響なし。

## 期待効果

- **EQUIV 正答率（現 70%）**: +5〜10pp 改善。INFERRED と自己評価した場合に追加トレースが促されることで、コード差異からの推論ジャンプによる NOT_EQ 誤判定が減少する。持続的失敗 3 件（15368, 13821, 15382）はいずれもトレース不足の NOT_EQ 誤判定であり、この Trace check が直接作用する。
- **NOT_EQ 正答率（現 100%）**: ±0〜+3pp。真の NOT_EQ ケースでは差異のあるコードパスをトレースすれば TRACED と自己評価でき、追加コストは発生しない。
- **判定方向の対称性**: Trace check は EQUIV / NOT_EQ いずれの方向の分析にも同様に適用されるため、判定の非対称操作には該当しない。
