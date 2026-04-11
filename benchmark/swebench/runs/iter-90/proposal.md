# Iteration 90 — 改善提案

## 1. Exploration Framework カテゴリと選定理由

**カテゴリ: E（表現・フォーマットを改善する）**

既存の検証ステップの適用範囲を指定する文言が曖昧で狭く、本来カバーすべきケースが抜け落ちている。
新しいステップや記録フィールドを追加せず、既存のディレクティブをより正確・包括的な表現に精緻化することで
副作用を最小化しながら推論品質を改善できる。

## 2. 改善仮説

**Step 4 の反事実トレース検証が適用される制御フローの範囲が過度に限定的であり、
ループ外の例外処理や条件付き返り値を持つ関数で非自明な挙動が見落とされている。
トリガー条件を「非自明な制御フロー全般（例外処理・ループ・多分岐条件式）」に広げることで、
トレーステーブルに記録される挙動の正確性が全体的に向上し、誤った PASS/FAIL 判定の伝播を減らせる。**

## 3. 変更箇所と変更内容

**対象**: `SKILL.md` § Step 4: Interprocedural tracing — Rules の最終箇条書き

### 変更前

```
- For exception handling inside loops or multi-branch control flows: after recording the inferred behavior, ask "if this trace were wrong, what concrete input would produce different behavior?" Trace that input through the code before finalizing the row.
```

### 変更後

```
- For non-trivial control flows — including exception handling, loops, and multi-branch conditionals — after recording the inferred behavior, ask "if this trace were wrong, what concrete input would produce different behavior?" Trace that input through the code before finalizing the row.
```

### 変更規模

**1 行の文言修正**（削除 0 行、変更 1 行）。

主な意味的差分:
- 「exception handling **inside loops**」→「exception handling（場所を問わない）」  
  ループ内に限定されていたため、関数レベルの try/except ブロックが対象外だった誤りを修正。
- 「loops」を独立したトリガーとして明示  
  例外処理を伴わない単純ループも対象に含める。
- 「multi-branch control flows」→「multi-branch conditionals」  
  制御フローの「分岐条件式」という意味をより明確化し、複雑な dispatch パターン等への過剰適用を抑制。

## 4. 期待効果

### 減少が期待される失敗パターン

| 失敗パターン | メカニズム |
|---|---|
| 関数の非自明な返り値が「自明」と誤判断されトレーステーブルに VERIFIED のまま記録される | ループ外の条件分岐や try/except が反事実チェックの対象になり、誤記録が上流で修正される |
| Compare モードで EQUIVALENT / NOT_EQUIVALENT いずれの方向にも関係する関数の挙動が不正確にトレースされる | トレーステーブルの精度向上が両方向の結論品質に均等に寄与する |
| 不完全な推論チェーン（論文エラー分析 §4.3: "Incomplete reasoning chains"） | トレースが誤っていた場合の具体的な入力を特定する習慣が強化される |

### EQUIV / NOT_EQ への対称効果

反事実チェックは「差異が存在するか」を問うのではなく「記録した挙動が正しいか」を問う。
挙動が正しく記録されることで、EQUIV 判定の精度（差異なしの確信度向上）と
NOT_EQ 判定の精度（差異の正確な特定）の両方が改善される。

## 5. failed-approaches.md との照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | 非該当。変更はトレース精度の向上であり、EQUIV/NOT_EQ いずれにも中立。 |
| #3 探索量の削減 | 非該当。チェック対象を広げるため探索は微増する（削減ではない）。 |
| #8 受動的な記録フィールドの追加 | 非該当。フィールド追加ではなく、既存の**能動的な検証行動**のトリガー条件を修正。 |
| #9 メタ認知的自己チェック | 非該当。「自分はやったか」の自己評価ではなく、コードを実際にトレースする行動を誘発。 |
| #18/#26 物理的証拠の必須化によるターン枯渇 | 非該当。追加される検証は「1 つの反事実入力を既読コード上でトレース」であり、新規ファイルの探索は要求しない。ターン消費の増加は 1 関数あたり 1 回の局所トレースに限定される。 |
| #22 抽象原則での具体物例示 | 非該当。変更は trigger の分類基準の明確化であり、特定のコード要素を名指していない。 |

その他の原則（#2, #4–7, #10–17, #19–21, #23–27）への抵触なし。

## 6. 変更規模の宣言

- **変更行数（追加・変更）: 1 行**（hard limit 5 行以内）
- **削除行数: 0 行**（制限外）
- 新規ステップ・新規フィールド・新規セクションの追加: **なし**
