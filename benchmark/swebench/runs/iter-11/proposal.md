# Iteration 11 — Proposal

## Exploration Framework カテゴリ: F

**カテゴリ F の定義**: 論文に書かれているが SKILL.md に反映されていない手法を探す、または論文の他のタスクモード（localize/explain）の手法を compare に応用する。

**今回選択したメカニズム: diagnose モードの Divergence Analysis を compare に応用**

docs/design.md によると、Fault Localization (Appendix B) の第3フェーズ「DIVERGENCE ANALYSIS」は「実装がテストの期待から diverge する具体的コード地点を CLAIM として明記する」構造を持つ。この形式は現在の compare モード certificate には存在しない。

compare の ANALYSIS OF TEST BEHAVIOR は per-test の PASS/FAIL trace を要求するが、"両変更の振る舞いが分岐する具体的コード地点" を記録する明示的な義務がない。結果として、subtly different な変更を「差異があるが無影響」と早期に切り捨てる Guardrail #4 違反（subtle difference dismissal）が起きやすい。

diagnose の `CLAIM D1: At [file:line], [code] produces [behavior] which contradicts PREMISE T[N]` パターンを compare の per-test trace の中に応用すれば、テスト結果比較の前に「どこで振る舞いが分岐するか」を証拠として固定でき、この見落としを構造的に防げる。


## 改善仮説

compare モードの per-test analysis において、両変更の振る舞いが分岐する具体的なコード地点を trace 中に明記する義務を課すことで、微細な差異の見落とし（subtle difference dismissal）を構造的に削減できる。


## SKILL.md の変更内容

**変更対象行** (SKILL.md 行 258):

```
変更前:
- Trace each test through both changes separately before comparing

変更後:
- Trace each test through both changes separately before comparing; for each test where outcomes differ, identify the specific file:line where the two changes first produce diverging behavior (applying Divergence Analysis from the diagnose mode)
```

**変更規模の宣言: 1 行、既存行への文言追加（文末に句読点で継続）**

この変更は compare checklist 内の既存指示行の精緻化であり、新規ステップ・フィールド・セクションの追加ではない。


## 一般的な推論品質への期待効果

**ターゲット失敗パターン: subtle difference dismissal (Guardrail #4)**

現状の問題: compare モードは per-test の PASS/FAIL 結果を比較するが、COUNTEREXAMPLE 記述に到達する前に「差異はあるが無影響」と判断する経路が存在し、Guardrail #4 がそれを事後的に防ごうとする。

変更後の効果: checklist の trace 義務に「diverge point の特定」が組み込まれることで、PASS/FAIL が異なるすべてのテストについて diverge 根拠を証拠として持った上で COUNTEREXAMPLE セクションに進むことが必須になる。これにより:

- NOT EQUIVALENT の見落とし（subtle difference を見つけても却下する）が減る → not_eq 精度の向上
- 逆に、COUNTEREXAMPLE が構造的に求められるため「確認できない差異を差異と断言する」過剰判定も抑制される → overall 精度の向上

**カテゴリ分類への対応**: フォーカスドメイン overall に対応する。diagnose の Divergence Analysis の核（「期待と実装の diverge 地点の明示」）を compare に移植することで、compare の両方向（equiv / not_eq）の判定根拠が強化される。


## failed-approaches.md の汎用原則との照合

### 原則 1: 探索を「正当化」から「特定シグナルの捜索」へ寄せすぎない

今回の変更は「既に差異が見つかったテスト」についての diverge 地点特定であり、探索全体の方向を固定するものではない。差異が見つからなければこの手順は適用されないため、確認バイアスを強める構造にはなっていない。→ 抵触なし

### 原則 2: 探索の自由度を削りすぎない

checklist への 1 行追加であり、仮説形成・観察・更新のループ（Step 3）には一切触れない。探索の幅は維持される。→ 抵触なし

### 原則 3: 結論直前の自己監査に新しいメタ判断を増やしすぎない

変更箇所は pre-conclusion self-check（Step 5.5）ではなく compare checklist の trace 義務の精緻化。既存チェック項目との役割重複もない（diverge point の特定は証拠記録であり、確信度評価ではない）。→ 抵触なし


## 変更規模の宣言

- 変更行数: 1 行（既存行への文末追記）
- 新規ステップ: なし
- 新規フィールド: なし
- 新規セクション: なし
- 削除行: なし
- hard limit (5 行) に対して: 1 行 / 5 行 → 適合
