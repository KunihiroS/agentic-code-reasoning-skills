# Iter-89 Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ E — 表現・フォーマットを改善する**

> 曖昧な指示をより具体的な言い回しに変える

`NO COUNTEREXAMPLE EXISTS` ブロックの `Conclusion` 行にあるプレースホルダ `[brief reason]` は、エージェントが発見したコードレベルの差異を「差異が存在するが影響しない」という根拠なき断言で退けることを暗黙に許容している。プレースホルダを具体化することで、発見された差異に対する**吸収メカニズムの明示**を要求し、エージェントの推論を「差異を見つけたか」だけでなく「差異がテスト結果に到達するかどうか」まで導く。

## 改善仮説

**仮説**: `NO COUNTEREXAMPLE EXISTS` の結論プレースホルダが曖昧であるため、エージェントは探索中に潜在的な反例を発見しても、それをテストアサーションへの影響ゼロと一言で片付けてしまう。プレースホルダを「発見された差異がテストアサーションに届く前のどこで吸収されるかを説明する」形式に精緻化することで、その説明が困難な場合（差異が実際に観測可能な場合）にエージェントが結論を再考するよう誘導できる。

## SKILL.md への変更

**場所**: Compare セクション → Certificate template → `NO COUNTEREXAMPLE EXISTS` ブロックの `Conclusion` 行

**変更前**:
```
  Conclusion: no counterexample exists because [brief reason]
```

**変更後**:
```
  Conclusion: no counterexample exists because [if a difference was found above, explain the mechanism that prevents it from reaching the test assertion; if nothing was found, state why the behavioral difference is structurally absent from the call path]
```

**変更規模**: 1 行の文言精緻化（既存行への refinement のみ、新規ステップ・フィールド・セクションなし）

## 一般的な推論品質への期待効果

| 失敗パターン | 現状 | 変更後 |
|---|---|---|
| 発見された差異を証拠なく「影響しない」と退ける（Guardrail #4 違反） | `[brief reason]` が曖昧なため一言で通過できる | 吸収メカニズムの説明を要求することで通過できなくなる |
| `not_eq` の見落とし（false EQUIVALENT） | 差異を発見しても結論部で手波いできる | 吸収メカニズムが説明できない場合、エージェントが反例と認識し直すよう誘導される |
| `equiv` への回帰リスク | 真に同等なケースでは差異吸収の説明は容易 | 低リスク：実際に吸収されているなら説明は書ける |

**減少が期待される失敗カテゴリ**:
- docs/design.md §4.3「Incomplete reasoning chains」— 差異発見後の追跡が途中で終わるパターン
- Guardrail #4「Do not dismiss subtle differences」の現実的な強制

## failed-approaches.md 汎用原則との照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | リスク低: 変更は `EQUIV` 結論時の推論内容を精緻化するが、判定閾値を直接移動させるものではない。真の EQUIV ケースでは吸収説明は書けるため、`equiv` への実質的な立証責任の引き上げは限定的 |
| #2 出力側の制約 | 非該当: 「こう答えろ」ではなく「発見された差異についてこう推論せよ」という処理側の指示 |
| #3 探索量の削減 | 非該当: 探索量には変化なし |
| #8 受動的記録フィールド | リスク低: `Conclusion` 欄は因果説明（吸収メカニズム）を要求しており、単なる記録以上の能動的推論を誘発する |
| #12 アドバイザリな非対称指示 | リスク認識あり: EQUIV 結論時にのみ適用される点は非対称。ただし真の EQUIV ケースでは説明コストが低いため、フォールバック誤判定を大量に引き起こす可能性は低い |
| #18 特定証拠への物理的裏付け要求 | 非該当: `file:line` の明示は要求していない。吸収「メカニズムの説明」のみ |
| #19 完全なエンドツーエンド立証義務 | 非該当: 全 Claim ではなく、`NO COUNTEREXAMPLE EXISTS` の Conclusion 行 1 か所への限定的な適用 |

## 変更規模の宣言

- **変更行数**: 1 行（既存行の文言精緻化）
- **削除行数**: 0 行
- **新規ステップ / フィールド / セクション**: なし
- **hard limit（5 行）への適合**: ✓
