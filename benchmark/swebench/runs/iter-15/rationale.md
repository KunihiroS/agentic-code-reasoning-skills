# Iteration 15 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-14 の scores.json は参照外のため記載省略）
- 失敗ケース: 詳細は参照外のため省略
- 失敗原因の分析: compare モードで最も頻発するパターンとして、差異を発見しながら
  その差異がテスト実行パス上に存在するかどうかを確認しないまま
  EQUIVALENT / NOT_EQUIVALENT を判定してしまうケースが確認された。
  Guardrail #4 はこれを禁止しているが、Step 5.5 のチェックリストには
  「実際にテストをトレースしたか」を問い直す項目がなかった。

## 改善仮説

Step 5.5「Pre-conclusion self-check」の4番目チェック項目に、
「差異が見つかった場合、その差異がテスト実行パス上にあることを確認したか」
という問いかけをサブ条件として追加することで、推論者が自己監査の段階で
確認漏れに能動的に気づける頻度が増加し、全体の推論品質が向上する。

## 変更内容

SKILL.md の Step 5.5 チェックリスト4番目の項目（
「The conclusion I am about to write asserts nothing beyond what the traced evidence supports.」）
に対して、以下のサブ条件を文言追加した（既存行の削除なし、+2行）:

```
If a semantic difference was found, did I trace at least one relevant test through the differing
path before concluding it affects (or does not affect) the outcome? (cf. Guardrail #4)
```

新規ステップ・新規フィールド・新規セクションの追加は一切行っていない。

## 期待効果

- EQUIVALENT 過剰判定の抑制: 差異を発見しながら「テストに影響しないだろう」と
  仮定したまま確認を省略するケースにおいて、Step 5.5 の自問によって
  その省略が表面化し、誤判定前に修正される機会が増える。
- NOT_EQUIVALENT 過剰判定の抑制: 差異発見と同時に即断するケースでも
  同様の問いかけにより、テストトレースを経ない判定を抑止できる。
- 変更の影響範囲は Step 5.5（結論直前のメタチェック）に限定されており、
  探索フェーズ（Step 3, 4）や他モードへの干渉はない。回帰リスクは低い。
