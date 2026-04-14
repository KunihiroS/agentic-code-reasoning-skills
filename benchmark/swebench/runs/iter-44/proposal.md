# Iter-44 Proposal

## Exploration Framework カテゴリ: C（強制指定）

カテゴリ C は「比較の枠組みを変える」に対応する。今回選択した具体的なメカニズムは
「差異の重要度を段階的に評価する」である。

### 選択理由

現行の STRUCTURAL TRIAGE（S1/S2/S3）は「差異が存在するか」のバイナリ判定に
留まっている。EDGE CASES セクションも "Test outcome same: YES / NO" という
二値分類のみで、差異が観測されたときにその差異がテスト結論を変えるほど
「重要か」を明示的に評価する手順がない。

この結果、次の失敗パターンが起きやすい:
- 軽微な意味差（型変換、例外の種類違い）を発見した直後に
  重要度評価をスキップして NOT EQUIVALENT と結論する（EQUIV の誤判定）
- 逆に、機能的に無関係な構造差（コメント、ログ追加など）を
  差異として記録しながら重要度を問わずスルーし、EQUIVALENT と誤判定する

カテゴリ C の「差異の重要度を段階的に評価する」メカニズムはこの空白を
既存のテンプレート内の精緻化として埋めることができる。

---

## 改善仮説（1 つ）

比較モードにおいて、差異を発見した時点でその差異が fail-to-pass テストの
アサーション到達経路上に位置するかどうかを明示的に評価させると、
差異の重要度の誤判定（小さな差異の過大評価、関係のない差異の見落とし）が
減り、EQUIV/NOT_EQUIVALENT 両方向の精度が向上する。

---

## SKILL.md のどこをどう変えるか

### 変更対象

SKILL.md の compare モード、EDGE CASES RELEVANT TO EXISTING TESTS セクション
（テンプレート内、現行 line 221–226 付近）。

### 変更前（現行）

```
EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
  E[N]: [edge case]
    - Change A behavior: [specific output/behavior]
    - Change B behavior: [specific output/behavior]
    - Test outcome same: YES / NO
```

### 変更後（提案）

```
EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
  E[N]: [edge case]
    - Change A behavior: [specific output/behavior]
    - Change B behavior: [specific output/behavior]
    - Difference reaches a test assertion: YES / NO (cite file:line if YES)
    - Test outcome same: YES / NO
```

### 変更規模の宣言

追加行数: 1 行（"- Difference reaches a test assertion: YES / NO ..." の 1 行）
削除行数: 0 行
合計変更規模: 1 行 — hard limit (5 行) 以内

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **差異の重要度の誤評価 (EQUIV 誤判定)**
   意味差が存在するにもかかわらず、それがテストのアサーション到達経路外だと
   明示できないまま EQUIVALENT に倒すケース。アサーション到達性の明示的な
   確認ステップを設けることで、「差異あり → 経路外 → テスト結果は同じ」
   という論理を証拠付きで通せるようになる。

2. **差異の重要度の誤評価 (NOT_EQUIVALENT 誤判定)**
   実装間の微細な違い（防御的ガード、追加ログなど）を発見した後、
   重要度の問いを飛ばして NOT EQUIVALENT と結論するケース。
   "Difference reaches a test assertion: NO" という記載要求が、
   安易な NOT EQUIVALENT 結論に対するブレーキとして機能する。

3. **根拠なし比較**
   EDGE CASES 記録が "YES / NO" の二値で終わり、どのアサーションに
   どう影響するかの証拠チェーンが省略されるケース。file:line 引用要求が
   証拠チェーンの欠落を表面化させる。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 抵触の有無 | 理由 |
|------|-----------|------|
| 探索シグナルを事前固定しすぎない | なし | 変更はアサーション到達性という判断軸の追記であり、探索手順の固定ではない。どのファイルを読むか・どの順番で読むかには一切介入しない。 |
| 探索の自由度を削りすぎない | なし | 既存フィールドへの 1 行の補足であり、読解順序・境界確定の順序を変えていない。 |
| 局所的な仮説更新を前提修正に直結させすぎない | なし | EDGE CASES テンプレートは探索後の記録欄であり、探索中の仮説更新フローとは独立している。 |
| 結論前の自己監査に必須メタ判断を増やしすぎない | なし | 変更先は Step 5.5（Pre-conclusion self-check）ではなく EDGE CASES テンプレートであり、結論直前のゲートに新しい判定軸を加えていない。 |

すべての汎用原則と非抵触。

---

## 変更規模の宣言（再掲）

- 追加行: 1 行
- 削除行: 0 行
- 新規ステップ・新規フィールド・新規セクション: なし
  （既存 EDGE CASES フィールド群への 1 行の精緻化追加）
- hard limit 5 行以内: 適合
