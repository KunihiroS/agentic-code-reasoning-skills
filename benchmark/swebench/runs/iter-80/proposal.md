# Iter-80 Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ B — 情報の取得方法を改善する**

具体的な下位方針:「コードの読み方の指示を具体化する」

### 選定理由

compare モードにおける伝播追跡ルール（compare チェックリスト）は、  
「変更された関数内で発生した振る舞いの差異」については追跡継続を要求している。  
しかし「変更された関数が、引数の変化を通じて未変更の下流関数の挙動を変える」という  
対称なケースがルールの射程に含まれていない。  
この欠落はコードの読み方の指示の不完全さであり、Category B の「読み方の指示を具体化する」  
アプローチで直接的に解消できる。

---

## 改善仮説

> 変更された関数の戻り値・副作用の差異だけでなく、変更された関数が未変更の下流関数へ  
> 渡す引数の差異も、テスト観測点まで追跡を継続する必要がある。  
> この対称なケースを既存の伝播追跡ルールに統合することで、  
> 変更後コードの「呼び出し側が変わった関数」を十分に読まないまま判定する  
> パターンを減らし、全体的な compare 精度が向上する。

---

## SKILL.md の変更内容

### 変更箇所

**Compare チェックリスト**（`## Compare` セクション末尾）の以下の行を変更する。

**変更前（既存行）:**
```
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), do not stop tracing at that function: read the function on the already-traced relevant test call path that consumes the changed output, and record whether it propagates or absorbs the difference before assigning the Claim outcome.
```

**変更後（精緻化）:**
```
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), or when a changed function passes a different value to an unchanged downstream function, do not stop tracing at that point: read the consuming function on the already-traced relevant test call path, and record whether it propagates or absorbs the difference before assigning the Claim outcome.
```

### 変更の要点

- 「変更された関数内の差異」という条件に **「変更された関数が未変更の下流関数へ異なる値を渡す」** ケースを OR 条件として追加。  
- 「do not stop tracing at that function」→「do not stop tracing at that point」に汎化（関数境界に限らない）。  
- 「read the function」→「read the consuming function」に明確化。  
- 既存の義務（伝播/吸収の記録、Claim 確定前の検証）はそのまま維持。

---

## 期待効果（一般的な推論品質への寄与）

### 減少が期待される失敗パターン

| 失敗パターン | メカニズム |
|---|---|
| 不完全な推論チェーン | 変更関数の出力変化を確認しただけで下流の挙動変化を確認せずに EQUIV と判定するケースが減る |
| 微細な差異の軽視（Guardrail 4） | 引数の変化が下流で異なる分岐を活性化する場合も追跡するよう明示される |
| 両方向への対称なカバレッジ | Change A / Change B のどちらのトレースにも同じ規則が適用されるため EQUIV / NOT_EQ の判定バランスを崩さない |

### overall フォーカスとの整合

追加条件はトレース継続の判断基準を拡張するのみで、  
「EQUIV を出しやすくする」「NOT_EQ を出しやすくする」という方向性を持たない。  
追跡するだけで、判定の方向は証拠が決める。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | **非抵触**: 変更前後の両側トレースに同一規則が適用される |
| #2 出力側の制約 | **非抵触**: 「こう答えろ」という出力規則ではなく、探索プロセスの指示 |
| #3 探索量の削減 | **非抵触**: 探索を削減しない。特定条件下で追跡を延長する |
| #8 受動的な記録フィールドの追加 | **非抵触**: 既存の記録義務を再利用し、新フィールドを追加しない |
| #9 メタ認知的自己チェック | **非抵触**: 自己評価チェックではなく、能動的なトレース継続の指示 |
| #12 アドバイザリな非対称指示 | **非抵触**: 対称な条件（Change A / B 共に適用）であり、片方の結論へのハードルを上げない |
| #18/#19 物理的立証の義務化 | **非抵触**: `file:line` の追加引用を新たに義務付けていない。既存の Claim 記録の延長のみ |
| #22 具体物の例示 | **非抵触**: 「引数の差異」「未変更の下流関数」は概念的記述であり、特定コード要素を名指ししない |

全原則に対して抵触なし。

---

## 変更規模の宣言

- **変更行数**: 1 行（既存行への文言精緻化）
- **削除行**: 0 行
- **新規ステップ・セクション・フィールド**: なし
- **hard limit (5 行) 充足**: ✅
