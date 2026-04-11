# Iteration 28 — 改善案提案

## 選択した Exploration Framework カテゴリ

**カテゴリ F: 原論文の未活用アイデアを導入する**  
サブ方向: **「論文の他のタスクモード（localize）の手法を compare に応用する」**

### 選択理由

| カテゴリ | 主な試行 | 評価 |
|---------|---------|------|
| A（順序・構造） | BL-4, BL-12, BL-14 | 逆方向推論（BL-14）含め試行済み |
| B（情報取得） | BL-5, BL-10, BL-11, BL-12 | 多数試行済み |
| C（比較の枠組み） | BL-1, BL-7, BL-13 | 多数試行済み |
| D（メタ認知） | BL-8, BL-9 | 構造的失敗パターンあり |
| E（表現・形式） | BL-6, BL-11 | 既存文言の変形にとどまる |
| **F（論文未活用）** | BL-8（RELEVANT 列）のみ | **今回の対象：Claim-Premise 接続形式** |

カテゴリ F において「BL-8（RELEVANT 列）」は試行済みだが、**論文の Fault Localization テンプレート（Appendix B）が Phase 3 で要求する「CLAIM D1 must reference a specific PREMISE」形式を compare モードの COUNTEREXAMPLE ブロックに移植する**というアプローチは未試行である。

論文 Appendix B より:
```
## Phase 3: Divergence Analysis
CLAIM D1: At [file:line], [code] would produce [behavior]
          which contradicts PREMISE T[N] because [reason]
- Each claim MUST reference a specific PREMISE and a specific code location
```

現在の compare モードの COUNTEREXAMPLE ブロックは「[reason]」が自由テキストであり、このPREMISE参照要件が欠如している。

---

## 改善仮説（1つ）

**仮説**: Compare モードの COUNTEREXAMPLE ブロックで反例の "[reason]" が自由テキストであるため、AI は「コード差異が存在する → NOT_EQUIVALENT」という論理ジャンプを PREMISES（特にテストが検査する挙動を記述する P3/P4）への参照なしに書ける。Fault Localization テンプレートが CLAIM D1 に「which contradicts PREMISE T[N]」という前提参照を必須とするように、compare の COUNTEREXAMPLE ブロックにも「By P[N]（何を検査するテストか）」への明示的参照を要求することで、コード差異 → テスト結果への論理接続の検証を強制し、EQUIV 偽陽性を削減できる。

**根拠**:  
- 論文の Error Analysis（§4.1.1）は「Dismissing subtle differences」と「Incomplete execution tracing」を主要失敗モードとして挙げる。前者はガードレール4で対処済み。後者のうち「incomplete tracing」の一形態として「コード差異は発見したが、そのテスト結果への因果連鎖を PREMISES と接続せずに結論する」パターンがある。  
- 論文の Fault Localization テンプレート（Phase 3）が "Each claim MUST reference a specific PREMISE" を要求するのは、まさにこの論理ギャップを埋めるためである。Compare モードにこの同一メカニズムを移植することは、論文の設計原則に沿った自然な拡張である。

---

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の Certificate template の **COUNTEREXAMPLE ブロック**と **NO COUNTEREXAMPLE EXISTS ブロック**を対称的に修正する。

### 現在の COUNTEREXAMPLE ブロック（行190–193）

```
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [reason]
  Test [name] will [FAIL/PASS] with Change B because [reason]
  Therefore changes produce DIFFERENT test outcomes.
```

### 変更後

```
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
  Test [name] will [PASS/FAIL] with Change A because [trace — cite file:line]
  Test [name] will [FAIL/PASS] with Change B because [trace — cite file:line]
  By P[N]: this test checks [assertion/behavior stated in P3 or P4], and the
           divergence above causes that assertion to produce a different result.
  Therefore changes produce DIFFERENT test outcomes.
```

### 現在の NO COUNTEREXAMPLE EXISTS ブロック（行195–201）

```
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, what input, what diverging behavior]
  I searched for exactly that pattern:
    Searched for: [specific pattern — test name, code path, or input type]
    Found: [result — cite file:line, or NONE FOUND with search details]
  Conclusion: no counterexample exists because [brief reason]
```

### 変更後

```
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, what assertion in P[N], what code difference
     would cause that assertion to produce a different result]
  I searched for exactly that pattern:
    Searched for: [specific pattern — test name, code path, or input type]
    Found: [result — cite file:line, or NONE FOUND with search details]
  Conclusion: no counterexample exists because [brief reason]
```

### 変更規模

- COUNTEREXAMPLE ブロック: 1行追加（`By P[N]:` フィールド）、"[reason]" に "cite file:line" 明示  
- NO COUNTEREXAMPLE ブロック: 既存の "[describe concretely: what test, what input, what diverging behavior]" を "what assertion in P[N]" を含む記述に差し替え（実質的に1行の言い換え）  
- 合計: +2行（追加）、1行変更。**20行以内の目安を大きく下回る。**

---

## EQUIV と NOT_EQ の両方の正答率にどう影響するかの予測

### EQUIV 正答率への影響（現在 6/10）

EQUIV 偽陽性のパターン（15368, 11179, 13821, 15382）では AI がコード差異を発見し、それを COUNTEREXAMPLE に記録して NOT_EQUIVALENT と結論している。`By P[N]` フィールドを必須にすることで、AI は「このコード差異が P3/P4 に記載されたテストのアサーション条件と、どう矛盾するか」を明示しなければならない。

- P3（テストが検査する挙動）がその差異を捉えていない場合、AI は有効な `By P[N]` を書けない。
- その場合、COUNTEREXAMPLE を成立させられないため、NOT_EQUIVALENT に誤判定しにくくなる。  
- **予測改善: +10〜20pp（EQUIV false positive が 1〜2 件削減）**

### NOT_EQ 正答率への影響（現在 7/10）

正当な NOT_EQ ケース（13417, 14787）では、P3/P4 がテストの検査内容を記述しており、コード差異がその検査内容に影響することを示す `By P[N]` は自然に書ける。

- BL-14（backward trace）と異なり、`By P[N]` は「P[N] に書いた前提と差異の接続を述べる」という低認知負荷の操作であり、完全な backward chain を要求しない。
- ターン消費の増加は COUNTEREXAMPLE 構造の精緻化（1行追加）にとどまり、BL-14 のような大幅なターン増加は見込まれない。  
- **予測: NOT_EQ 正答率への悪影響は軽微（0〜-5pp）**

---

## failed-approaches.md のブラックリストおよび共通原則との照合結果

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|----------------|
| BL-1 | ABSENT 定義追加 | 無関係（比較対象の定義変更ではない） |
| BL-2 | NOT_EQ 証拠閾値の厳格化 | 異なる（閾値変更ではなく Premise 参照要件） |
| BL-5 | P3/P4 の形式強化 | 異なる（PREMISES ではなく COUNTEREXAMPLE ブロックを修正） |
| BL-7 | CHANGE CHARACTERIZATION ステップ追加 | 異なる（分析前のラベル生成ではなく、証拠提示の形式変更） |
| BL-8 | Relevant to 列の追加（受動的記録） | 異なる（P[N] 参照は「論理接続の検証」であり単なる記述ではない） |
| BL-9 | Trace check 自己チェック行 | 異なる（AI の行為を自己評価させない。既存 PREMISES との論理接続を問う） |
| BL-12 | テストソース先読み固定順序 | 無関係（探索順序の変更ではない） |
| BL-13 | Key value データフロートレース欄 | 異なる（変数追跡フィールドではなく Premise 参照フィールド） |
| BL-14 | チェックリストへの backward trace 追加 | **実装形態・認知負荷・対称性の3点で異なる（後述）** |

#### BL-14 との詳細な差異

| 観点 | BL-14 | 本提案 |
|------|-------|--------|
| 実装箇所 | チェックリスト（アドバイザリ） | テンプレート構造（COUNTEREXAMPLE ブロック） |
| 適用対象 | NOT_EQ 主張時のみ | COUNTEREXAMPLE（NOT_EQ）と NO COUNTEREXAMPLE（EQUIV）の両ブロックを**対称修正** |
| 要求する推論 | アサーションから逆算してコード差分まで因果連鎖を辿る（backward chain 全体） | P[N] に記載した前提との論理接続を述べる（1文の接続確認） |
| 認知負荷 | 高（複数ステップの逆方向推論） | 低（既に確立した PREMISES との照合） |

### 共通原則との照合

| 原則 | 照合結果 |
|------|---------|
| #1 判定の非対称操作は必ず失敗する | COUNTEREXAMPLE と NO COUNTEREXAMPLE を**対称修正**するため、一方への有利化ではない |
| #2 出力側の制約は効果がない | 出力形式の変更ではなく、証拠提示の**論理接続形式**の変更（処理側の改善） |
| #3 探索量の削減は常に有害 | 探索量を削減しない |
| #5 テンプレートの過剰規定は探索視野を狭める | PREMISES（既存情報）との参照を要求するのみ。何を探索するかは制約しない |
| #6 対称化は既存制約との差分で評価せよ | 実効差分: COUNTEREXAMPLE に「P[N] との論理接続フィールド」（新規）、NO COUNTEREXAMPLE に「P[N] のアサーション条件」へのフォーカス（表現精緻化）— **対称的な差分** |
| #8 受動的記録フィールドは能動的検証を誘発しない | `By P[N]:` は単なる記述欄ではなく「既に確立した PREMISES との矛盾を示す」論理的接続の検証であり、能動的な前提確認を促す |
| #12 アドバイザリな非対称指示も立証責任引き上げとして作用する | 本提案はチェックリスト（アドバイザリ）ではなくテンプレート構造の変更（両方向対称）であるため、この原則は適用されない |

---

## 変更規模のまとめ

- 追加行数: 2行
- 変更行数: 1行（言い換え）
- 削除行数: 0行
- **合計 diff: 約3行。20行以内の目安を大きく下回る。**
