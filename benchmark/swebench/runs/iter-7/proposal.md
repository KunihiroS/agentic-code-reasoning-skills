# Iteration 7 — 改善提案

## iter-6 スコア分析

**スコア**: 75%（15/20）

| ケース | 正解 | 予測 | 分類 |
|--------|------|------|------|
| django__django-15368 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陽性 |
| django__django-13821 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陽性 |
| django__django-15382 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陽性 |
| django__django-14787 | NOT_EQUIVALENT | EQUIVALENT | NOT_EQUIV 偽陰性 |
| django__django-12663 | NOT_EQUIVALENT | UNKNOWN | NOT_EQUIV 偽陰性 |

---

## 選択した Exploration Framework カテゴリ

**カテゴリ A: 推論の順序・構造を変える**

> ステップの実行順序を入れ替える

### 選択理由

iter-6 の EQUIV 偽陽性 3 件（15368, 13821, 15382）の共通パターン:

> コード差異を発見 → テストがそのパスを通るか未確認 → NOT_EQUIVALENT と結論

現在の Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` は：

```
For each relevant test:
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  ...
```

この構造では、エージェントは**コード差異を起点**に分析を始め、
「コード構造上テストに影響するだろう」という推論でそのまま PASS/FAIL を結論できる。

D2 の定義では「pass-to-pass テストは変更コードがコールパスにある場合のみ relevant」と
書かれているが、これは DEFINITION（背景情報）であり、分析中の能動的なステップではない。

**変更の本質**: 各テスト分析の最初に「このテストのコールパスは変更コードに到達するか」を
確認するステップを明示的に挿入し、到達しない場合は即座に SAME と判断させる。
これは「コード差異を先に見る」から「テストの視点から入る」への推論順序の転換である。

カテゴリ A の「ステップの実行順序を入れ替える」に直接対応する。

---

## 改善仮説（1つ）

**Compare テンプレートの各テスト分析ブロックの先頭に、テストのコールパスが
変更コードに到達するか確認する Reachability ステップを挿入することで、
エージェントがコード構造から判定方向を推論する前に、テスト到達性を検証する
機会を確保し、テスト到達性未確認の NOT_EQUIVALENT 結論を減らすことができる。**

根拠：
- D2 の「pass-to-pass テストはコールパスにある場合のみ relevant」という意図を、
  分析ステップとして明示化するもの。論文 Appendix A の設計意図の実装を完全化する（F 補強）。
- YES/NO の 2値判断（"Does this test's call path reach the changed code?"）は、
  判定方向（EQUIV/NOT_EQUIV）と直交する事実の確認であり、
  BL-7 の「変更の性質ラベル（production/test/both）」のような判定方向への
  アンカリングを引き起こさない。
- 「条件分岐: NO なら即 SAME」という構造により、到達しないテストで
  コード差異の影響を推論するショートカットを防ぐ。
- 到達性確認は結論フェーズの制約（BL-6）ではなく分析フェーズの開始点であり、
  立証責任の引き上げ（BL-2）には該当しない。

---

## SKILL.md のどこをどう変えるか

**変更箇所**: Compare セクション、Certificate template の `ANALYSIS OF TEST BEHAVIOR`、
`For each relevant test` ブロック（fail-to-pass 用・pass-to-pass 用の両方）。

### 変更前（fail-to-pass ブロック）

```markdown
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後（fail-to-pass ブロック）

```markdown
For each relevant test:
  Test: [name]
  Reachability: Does this test's call path reach the changed code?
    [YES — cite the function call at file:line that leads to the changed code]
    [NO  — state what was searched and where the path ends]
  (If NO: Comparison is SAME — skip to next test)
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

pass-to-pass ブロックも同様に変更（同一の 4 行を挿入）。

**変更規模**: 4 行挿入 × 2 箇所 = 計 8 行追加、削除・変更 0 行。
影響範囲は Compare モードの certificate template の 2 ブロックのみ。
PREMISES, COUNTEREXAMPLE, FORMAL CONCLUSION, Guardrails, Step 3–5.5、
localize/explain/audit-improve には変更なし。

---

## EQUIV・NOT_EQ 正答率への予測影響

### EQUIV 正答率（iter-6: 7/10 = 70%）

- 偽陽性 3 件（15368, 13821, 15382）はいずれも「コード差異があるから NOT_EQUIV」という
  パターン。Reachability ステップで「このテストはその関数を呼ぶか？」を問われると、
  コールパスを実際に確認せずに YES と書けない（file:line 引用が必要）。
  到達しないと分かれば即 SAME となり、偽陽性が減る。
- **予測**: 7/10 → 8〜9/10（1〜2 件改善）

### NOT_EQ 正答率（iter-6: 8/10 = 80%）

- 真の NOT_EQUIV ケースでは、テストは変更コードに到達している（それが NOT_EQUIV の理由）。
  Reachability ステップには「YES — [file:line]」と自然に書けるため、
  実質的な追加コストは小さい。
- 14787 は NOT_EQUIV 偽陰性（AI が EQUIV と結論）。Reachability チェックが
  「テストは変更コードに到達する」と確認させることで、NOT_EQUIV の根拠が
  強まる可能性があり、微改善が期待できる。
- 12663 は 31 ターンで UNKNOWN。Reachability ステップが１行追加されるが、
  コールパス確認は元来必要な作業であり、大幅なターン増加は見込まれない。
  ターン消費を悪化させるリスクは低い。
- **予測**: 8/10 → 8〜10/10（回帰なし〜若干改善）

---

## ブラックリスト・共通原則との照合

| 項目 | 判定 | 根拠 |
|------|------|------|
| BL-1（ABSENT 定義追加） | **非該当** | 新定義・カテゴリの追加なし |
| BL-2（NOT_EQ 閾値厳格化） | **非該当** | 結論フェーズの制約ではなく分析フェーズの開始ステップ。ALL テストに対称適用 |
| BL-3（UNKNOWN 禁止） | **非該当** | 出力制約なし |
| BL-4（早期打ち切り） | **非該当** | 到達なし→SAME は探索短縮ではなく正しい判断の明示化 |
| BL-5（P3/P4 過剰規定） | **非該当** | PREMISES ではなく ANALYSIS ブロック内。記録フォーマット指定なし |
| BL-6（Guardrail 4 対称化） | **非該当** | Guardrails 変更なし。機能は「結論前の義務」ではなく「分析の開始順序」 |
| BL-7（中間ラベル生成） | **非該当** | YES/NO は到達性という事実。判定方向（EQUIV/NOT_EQ）ラベルではない |
| BL-8（Relevant to 列追加） | **非該当** | Relevant to は Step 4 テーブルの受動記録列。Reachability は分析ブロックの条件分岐付き決定ステップ |
| BL-9（Trace check 自己チェック） | **非該当** | 「自分はトレースしたか？」という自己評価ではなく「コードはこのパスに到達するか？」という外部事実の確認 |
| 原則 #1（非対称操作） | **非該当** | fail-to-pass・pass-to-pass 両ブロック・両方向に均等適用 |
| 原則 #2（出力側制約） | **非該当** | 分析プロセスの入力側（何を先に確認するか）を変更 |
| 原則 #3（探索量削減） | **非該当** | 到達性確認というステップを追加。削減方向ではない |
| 原則 #4（同じ方向の変更） | **非該当** | 推論の開始順序という新しいメカニズム |
| 原則 #5（視野の制約） | **非該当** | 「コールパスが到達するか」はオープンエンドな確認。記録すべき情報を限定しない |
| 原則 #6（対称化の差分評価） | **非該当** | 既存制約の対称化ではなく新ステップの挿入 |
| 原則 #7（アンカリング） | **非該当** | 到達性（YES/NO）は判定方向へのショートカットにならない |
| 原則 #8（受動記録） | **非該当** | 条件分岐付き決定ゲート。「NO なら即 SAME」という能動的帰結がある |
| 原則 #9（メタ認知精度限界） | **非該当** | コード構造についての外部事実確認。エージェント自身の行動の自己評価ではない |

### BL-8 との詳細区別

BL-8 失敗の本質: 「受動的な記録フィールドの追加は能動的な検証を誘発しない」

本提案との違い:
1. **場所**: BL-8 は Step 4 探索テーブル（探索フェーズ）; 本提案は ANALYSIS ブロック（分析フェーズ）
2. **構造**: BL-8 は自由記述の記録列; 本提案は YES/NO ＋ file:line の条件分岐ゲート
3. **帰結**: BL-8 は記録後の行動指示なし; 本提案は「NO → 即 SAME でスキップ」という強制帰結
4. **視点**: BL-8 は「この関数はどのテストに関係するか（関数→テスト）」; 本提案は「このテストは変更コードに到達するか（テスト→コード）」

---

## 変更規模

- **変更行数**: 4 行追加 × 2 箇所 = 計 8 行
- **変更種別**: 純粋追加（既存行の削除・変更なし）
- **制約**: 20 行以内 ✓
