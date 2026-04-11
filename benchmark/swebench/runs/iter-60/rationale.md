# Iteration 60 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70% (14/20)
- 失敗ケース: 11179, 15382, 14787, 14122, 12663, 15368
- 失敗原因の分析: iter-56 が D2(b) に追加した 2 行（BL-22 等価）が pass-to-pass テストの関連性確認にトレース義務を課し、NOT_EQ ケース（14787, 14122, 12663）で 31 ターン枯渇による UNKNOWN を引き起こした。

## 改善仮説

D2(b) の「`Verify this by tracing the test's execution; do not assume relevance from file proximity, shared module, or test-level changes such as deletion.`」2 行は BL-22 等価のネガティブプロンプトであり（原則 #16）、高コスト検証義務によるターン枯渇 UNKNOWN の直接原因である。この 2 行を削除することで NOT_EQ 側の UNKNOWN が解消し、スコアが 70% → 80〜85% に回復する。

## 変更内容

`## Compare > ### Certificate template > DEFINITIONS > D2(b)` から以下の 2 行を削除した（追加なし）:

```
        Verify this by tracing the test's execution; do not assume relevance
        from file proximity, shared module, or test-level changes such as deletion.
```

チェックリスト item 6 の変更（"not merely the internal execution path"）は保持し、iter-56 での 13821 正答を維持する。

## 期待効果

- 14787, 14122, 12663: NOT_EQ UNKNOWN → NOT_EQ ✓ に回復（予測 +3 件）
- 13821: チェックリスト変更保持により EQUIV 正答を維持
- 総合: 14/20（70%）→ 16〜17/20（80〜85%）予測
