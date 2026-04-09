# Iteration 113 — Proposal

## Exploration Framework カテゴリ: F（強制指定）

### カテゴリ内での具体的なメカニズム選択理由

カテゴリ F には以下の3つのメカニズムが示されている:

1. 論文に書かれているが SKILL.md に反映されていない手法を探す
2. 論文の他のタスクモード（localize, explain）の手法を compare に応用する
3. 論文のエラー分析セクションの知見を反映する

今回はメカニズム 2（explain の手法を compare に応用）を選択する。

理由: explain モードの certificate template は「DATA FLOW ANALYSIS」セクションを
持ち、各キー変数について "Created at / Modified at / Used at" の 3 点を追跡する。
これは「同一入力を受けた両実装が同一の状態変化を経て同一の返り値を生む」かを
確認するための最も直接的な観点であり、compare モードの NO COUNTEREXAMPLE EXISTS
ブロックにそのまま応用できる。しかし現行 SKILL.md の compare テンプレートには
このデータフロー観点が反映されていない。

一方メカニズム 1（未活用手法の探索）や 3（エラー分析の知見）については、
docs/design.md §"Turning error analysis into guardrails" が示す通り、主要な
失敗パターン（名前からの推定、根本原因の混同、不完全な推論チェーン等）は
Guardrails に既に反映されている。したがって最も未活用の余白はメカニズム 2 にある。

---

## 改善仮説

compare モードで「等価」と正しく判定するためには、変更箇所を通過する制御フロー上の
キー変数が両実装で同一の状態遷移をたどることを確認しなければならない。
しかし現行の NO COUNTEREXAMPLE EXISTS ブロックは「what test, what input, what
diverging behavior」という抽象的な反例フォーマットのみを示しており、何を具体的に
探せばよいかが曖昧である。

explain モード由来のデータフロー観点（変数の最終値・返り値・副作用の一致確認）を
NO COUNTEREXAMPLE EXISTS ブロックの探索指針として明示することで、equiv 判定の
counterexample 探索が「より具体的な物理的パターン」に着地するようになり、
「差異を見落として誤 EQUIV」を出す Guardrail #4 系の失敗が減ると予想する。

---

## SKILL.md の変更内容

### 変更箇所

compare テンプレート内 NO COUNTEREXAMPLE EXISTS ブロックの
`Searched for: [specific pattern — test name, code path, or input type]` 行を
以下に置き換える（1行変更）:

```
変更前:
    Searched for: [specific pattern — test name, code path, or input type]

変更後:
    Searched for: [data-flow pattern — key variable's final value, return value,
      or side-effect that would differ; plus test name or code path that would
      observe the divergence]
```

#### 変更規模の宣言

- 変更行数: 1 行（既存行への文言精緻化）
- 削除行: 0 行
- 新規ステップ・新規フィールド・新規セクション: なし
- hard limit（5 行）: 1 行 ≤ 5 行 → 適合

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **Guardrail #4「微妙な差異の却下」系の誤 EQUIV**:
   現行の「test name, code path, or input type」という探索指針は「どのテストが
   関係するか」への注意を促すが、「何の値が変わるか」への注意は促さない。
   データフローパターン（final value / return value / side-effect）を明示することで、
   エージェントは両実装が同一の観測可能な結果を生むかを確かめる具体的な問いを
   持って探索に入れる。

2. **Guardrail #5「不完全な推論チェーン」系の誤 EQUIV**:
   explain モードの DATA FLOW ANALYSIS が防ごうとしているのと同じ問題——下流コードが
   すでに差異を吸収しているかどうかを確認せずに結論を出してしまうパターン——が
   compare モードの equiv 判定でも発生する。返り値・副作用レベルでの一致確認を
   探索指針に組み込むことで、この下流確認の抜けを減らす。

### NOT_EQ 精度への影響

変更は NO COUNTEREXAMPLE EXISTS ブロック（EQUIV と主張するときにのみ記入する
ブロック）の探索指針の精緻化であり、NOT_EQ 判定のロジックには直接触れない。
探索量を増やすものでも、立証責任を非対称化するものでもない。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| #1 判定の非対称操作 | 抵触しない。変更は EQUIV 判定の counterexample 探索指針を精緻化するが、閾値や立証責任の非対称な引き上げではない。NOT_EQ 判定への反作用もない。 |
| #2 出力側の制約 | 抵触しない。「こう答えろ」ではなく、「何を探すか」という入力側・処理側の改善。 |
| #3 探索量の削減 | 抵触しない。探索指針の精緻化であり削減ではない。 |
| #5 入力テンプレートの過剰規定 | 抵触しない。探索対象を「限定」するのではなく「具体化」している。data-flow pattern は既存の test name / code path / input type と並列に列挙されており、排他的置換ではない。 |
| #7 分析前の中間ラベル生成 | 抵触しない。NO COUNTEREXAMPLE EXISTS は分析後の反証ステップであり、中間ラベルの事前生成ではない。 |
| #8 受動的記録フィールドの追加 | 抵触しない。新規フィールドの追加ではなく、既存の探索パターン指定行の文言精緻化。 |
| #12 アドバイザリな非対称指示 | 抵触しない。NOT_EQ のときにのみ追加要求を課すものではない。 |
| #18/#19 証拠の物理的裏付け要求 | 抵触しない。「file:line の引用」を新たに義務付けるものではない。 |
| #22 具体物の例示による過剰適応 | 抵触しない。特定のコード要素名ではなく、「final value」「return value」「side-effect」という抽象的な状態カテゴリで指示している。 |
| #26 中間ステップでの過剰な物理的検証要求 | 抵触しない。義務（must）ではなく、探索パターンの候補として示す形式。 |
| その他（#4, #6, #9〜#11, #13〜#17, #20, #21, #23〜#25, #27） | いずれも変更の方向・規模・対象と無関係または抵触しない。 |

---

## 参考: 変更前後の差分イメージ

```
--- SKILL.md (before)
+++ SKILL.md (after)
@@ compare template, NO COUNTEREXAMPLE EXISTS block @@
-    Searched for: [specific pattern — test name, code path, or input type]
+    Searched for: [data-flow pattern — key variable's final value, return value,
+      or side-effect that would differ; plus test name or code path that would
+      observe the divergence]
```

変更は 1 行の文言置き換えのみ。
新規ステップ・新規フィールド・新規セクションの追加はない。
研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）は維持される。
