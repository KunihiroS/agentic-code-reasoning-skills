# Iter-98 改善提案

## Exploration Framework カテゴリ

**Category B — 情報の取得方法を改善する**

選定理由: `equiv` 失敗の主因は「コードレベルの差異を発見した後、その差異がテストアサーションの観測スコープに届いているかどうかを確認しないまま DIFFERENT 判定を下すこと」にある。改善すべきは探索量でも比較枠組みでもなく、トレースの「読み方の具体的な完了条件」である。Category B の「コードの読み方の指示を具体化する」に相当する。

---

## 改善仮説

**テスト単位の PASS/FAIL 判定において、コードパスのトレースはコードレベルの差異到達点で完結させるのではなく、テストのアサーションが実際に検査する振る舞いへの接続まで明示的に要求する必要がある。**

コードレベルの差異は存在するが、テストのアサーションがその差異を観測しない場合、両変更のテスト結果は同一になる。現行テンプレートの `[trace through code — cite file:line]` はトレースの到達点を規定していないため、エージェントがコードの差異点でトレースを打ち切り、アサーション到達前に DIFFERENT と結論づける誤判定が発生しうる。「トレースをアサーションが検査する内容で終わらせる」という完了条件を明記することで、このギャップを埋められる。

---

## 変更内容

SKILL.md の Compare > Certificate template > ANALYSIS OF TEST BEHAVIOR 内、per-test 分析の Claim 行を以下のとおり変更する（2 行変更）。

**変更前:**
```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
```

**変更後:**
```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line — ending at what the assertion checks]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line — ending at what the assertion checks]
```

---

## 期待効果

### `equiv` 精度の向上

- 真に EQUIVALENT なケース（コードは異なるが同一テスト結果）において、エージェントはトレースをアサーションのスコープまで延長するよう促される。コードの差異がアサーションの検査対象に届かないことを明示的に確認できるため、誤った DIFFERENT 判定が減少する。
- これにより「コードレベルの差異を発見 → アサーション到達前に DIFFERENT と断定」という `equiv` の典型失敗パターンが抑制される。

### NOT_EQ 精度への影響

- 真に NOT_EQUIVALENT なケースでは、コードの差異はアサーションの検査対象に届く。したがって「ending at what the assertion checks」の要件は自然に満たされ、既存の正答を崩さない。

### 変更の対称性

- 変更は Change A のトレース (C[N].1) と Change B のトレース (C[N].2) に同一の完了条件を課しており、どちらか一方の判定方向に閾値を移動させるものではない。コードパスとアサーションの接続を確認するという推論プロセス自体の品質向上である。

---

## failed-approaches.md 照合結果

| 原則番号 | 内容要約 | 抵触判定 | 理由 |
|---------|---------|---------|------|
| #1 | 判定の非対称操作 | **問題なし** | 変更は C[N].1 と C[N].2 の両方に同一条件を課し、EQUIV / NOT_EQ の判定閾値を移動させていない |
| #5 | テンプレートの過剰規定 | **問題なし** | 記録すべき情報の種類を制限するのではなく、トレースの完了条件を明示するのみ |
| #18 | 特定証拠への物理的裏付け要求 | **問題なし** | `file:line` の引用は既存要件のまま変更なし。追加は「アサーションが検査する内容への接続」という推論上の完了条件であり、新たなコード要素の発見・引用義務ではない |
| #26 | アサーション命名の義務化 | **問題なし** | 「ending at what the assertion checks」は推論チェーンの接続を示す指示であり、特定アサーション要素を `file:line` で命名・特定させる義務ではない |
| #9 | メタ認知的自己チェック | **問題なし** | 「自分はトレースしたか？」型の自己評価チェックではなく、トレースの到達条件を明示する指示変更 |
| #3 | 探索量の削減 | **問題なし** | 探索を削減しない。必要に応じてトレースをアサーション接続まで延長する |
| その他 | #2, #4, #6, #7, #8, #10–#17, #19–#25, #27 | **該当なし** | 上記以外の原則には抵触しない |

---

## 変更規模の宣言

- **変更行数: 2 行**（既存行への文言追加・精緻化のみ）
- 新規ステップ・新規フィールド・新規セクションの追加なし
- 削除行なし
- Hard limit（5 行）以内
