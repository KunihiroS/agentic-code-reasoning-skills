# Iteration 8 — 改善提案

## 1. 選択した Exploration Framework カテゴリと理由

**カテゴリ F: 原論文の未活用アイデアを導入する**

理由: `localize` モードの **Phase 3（DIVERGENCE ANALYSIS）** に「実装がテストの期待からどこで逸脱するかを特定する」という手法が定義されているが、`compare` モードのテンプレートにはこの「乖離点の特定」視点が組み込まれていない。`compare` モードは現在、各テストを Change A と Change B の2つの独立トレースで分析する（"Claim C[N].1 / C[N].2" 形式）が、この設計では「コードが変わっている」という事実から「テスト結果が変わる」という結論へのジャンプを防げない。論文の `localize` テンプレートにある「乖離点の明示」を `compare` モードに応用することで、両者が実際にどこで異なる値を生じるかを証拠として要求できる。

カテゴリ A（推論の順序・構造を変える）とも重複するが、本質は論文の他モードの手法移植であるため F を主カテゴリとする。

---

## 2. 改善仮説

**compare モードのテスト分析ブロックを「乖離点ファースト（Divergence-First）トレース」構造に変更することで、エージェントが Change A と Change B の実際の値レベルでの相違点を明示せずに NOT_EQUIVALENT 結論を出す誤判定（EQUIV 偽陽性）を防ぎ、かつ NOT_EQUIVALENT 判定に必要な証拠収集を現在の2重独立トレースより効率化できる。**

---

## 3. SKILL.md のどこをどう変えるか

### 変更対象

`compare` モード、Certificate template 内の `ANALYSIS OF TEST BEHAVIOR` セクション  
— fail-to-pass テスト用ブロック（6 行）と pass-to-pass テスト用ブロック（5 行）の **Claim 形式を置き換える**。

### 変更前（fail-to-pass ブロック）

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後（fail-to-pass ブロック）

```
For each relevant test:
  Test: [name]
  Divergence: Identify the first point in this test's code path where
              Change A and Change B produce different values or behavior.
    A at [file:line]: [specific value or behavior — VERIFIED by reading source]
    B at [file:line]: [specific value or behavior — VERIFIED by reading source]
    (If values are identical at every traced point through the test assertion:
     Comparison is SAME — omit Claim below)
  Claim C[N]: Test will [PASS with A / FAIL with B] or [FAIL with A / PASS with B]
              because [trace from divergence point to test assertion — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更前（pass-to-pass ブロック）

```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後（pass-to-pass ブロック）

```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Divergence: Where in this test's code path do A and B produce different values?
    A at [file:line]: [value or behavior — VERIFIED]
    B at [file:line]: [value or behavior — VERIFIED]
    (If identical at every traced point: Comparison is SAME — omit Claim below)
  Claim C[N]: behavior differs because [trace from divergence to assertion — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

**変更規模**: 計 +10 行 / -11 行（ネット -1 行）。20 行以内。  
**変更外**: DEFINITIONS、PREMISES、EDGE CASES、COUNTEREXAMPLE/NO COUNTEREXAMPLE、FORMAL CONCLUSION、Step 1–5.5、Guardrails、他モードすべて変更なし。

---

## 4. EQUIV・NOT_EQ 正答率への影響予測

### EQUIV 正答率（現在 7/10 → 予測 8〜9/10）

現在の EQUIV 偽陽性（15368、13821、15382）の共通パターン（BL-10 Fail Core より）:  
「テストのコールパスは変更コードに到達しているが、コード差異がテスト結果を変えない」。現行テンプレートでは Claim C[N].1/C[N].2 の "trace through code" がコード差異の発見で打ち切られ、「差異あり → FAIL」のジャンプが可能。

変更後: `Divergence` 欄は `A at [file:line]: [specific value]` vs `B at [file:line]: [specific value]` という**値レベルの明示**を要求する。Change A と Change B が当該コードパスで**同じ値を返す**（EQUIV ケースの実態）ならば、エージェントは "values are identical at every traced point" と記録して Comparison を SAME にせざるを得ない。コード構造上の差異だけでは DIFFERENT と書けない。

### NOT_EQ 正答率（現在 7/10 → 予測 回帰なし〜微改善）

NOT_EQUIV UNKNOWN ケース（14787、11433、12663）: 31 ターン到達による UNKNOWN。  
変更後: 1 テストあたりの分析が「Claim A + Claim B」の2重独立トレース（5 行）から「Divergence 確認 + 条件付き Claim」（5〜6 行）に変わる。差異を発見した時点で Claim は 1 本のみ書けばよく、不要なトレースを省ける。ターンオーバーヘッドの純増はなく、NOT_EQ 差異が存在するケースではむしろ集中的に差異を探すため、証拠発見が早期化する可能性がある。

**非対称効果の確認**: 変更は EQUIV 方向の「証拠閾値の引き上げ」ではなく、「実際の値差異の明示化」であり、NOT_EQ 判定のハードル変化はない。真の NOT_EQUIV ケースでは乖離点に実際の値差異が存在するため、Divergence 欄は自然に `A: returns X / B: returns Y` と埋まる。

---

## 5. failed-approaches.md ブラックリストおよび共通原則との照合

| 項目 | 照合結果 | 根拠 |
|------|---------|------|
| BL-1（ABSENT 定義）| 非該当 | テストの比較対象を除外する変更ではない |
| BL-2（NOT_EQ 証拠閾値厳格化）| 非該当 | NOT_EQ 側の立証責任を上げていない。COUNTEREXAMPLE 節は無変更。変更は ANALYSIS 内の記述形式のみ |
| BL-3（UNKNOWN 禁止）| 非該当 | 出力制約ではなく分析プロセスの変更 |
| BL-4（CONVERGENCE GATE）| 非該当 | 探索を打ち切るゲートではなく、乖離点の明示を要求する記述形式変更 |
| BL-5（P3/P4 の過剰規定）| 非該当 | 前提収集テンプレートへの変更なし |
| BL-6（Guardrail 4 の対称化）| 非該当 | Guardrail は無変更。既存制約との差分は「値レベルの差異明示」のみ。方向の非対称性なし |
| BL-7（分析前ラベル生成）| 非該当 | 「Change の性質のラベル付け」ではなく「テスト実行パス上での値差異の証拠収集」。ラベルではなく証拠を要求している |
| BL-8（Relevant-to 列追加）| 非該当 | テーブルへの受動的記録フィールド追加ではなく、Claim の記述構造そのものの変更 |
| BL-9（Trace check 自己チェック）| 非該当 | 自己評価ではなく、外部検証可能な file:line 証拠（値の明示）を要求 |
| BL-10（Reachability ゲート）| 非該当 | ゲート条件が異なる。Reachability は「到達するか（ほぼ常に YES）」。Divergence は「何の値が異なるか」。前者は必要条件の検査、後者は十分条件の構築 |

### 共通原則との照合

| 原則 | 照合結果 |
|------|---------|
| #1 判定の非対称操作 | EQUIV/NOT_EQUIV 双方向に対称適用。Claim が1本になることはいずれの方向にも有利に働かない |
| #2 出力側の制約は効果なし | 出力制約ではなく分析プロセス（何を書くか）の変更 |
| #3 探索量の削減は有害 | 乖離なしの場合に Claim 2 本を省略するが、これは情報ゼロの冗長な記述の省略であり、証拠収集そのもの（ファイルを読む行為）は減らない |
| #4 同じ方向の変更は同じ結果 | 過去の失敗方向（NOT_EQ 閾値操作）と異なるメカニズム（記述形式の変更） |
| #5 テンプレートの過剰規定は視野を狭める | 「何を記録するか」の規定追加ではなく、既存 Claim の記述形式を具体化するもの。ファイル探索の視野は制約しない |
| #6 対称化は差分で評価 | 変更前後の差分は「Claim の shape 変更」のみ。EQUIV/NOT_EQ いずれの立証責任にも実効的な非対称差分なし |
| #7 中間ラベル生成はアンカリング | Divergence 欄はラベルではなく、値の証拠（A: value-X / B: value-Y）を要求する |
| #8 受動的記録フィールドは検証を誘発しない | Divergence 欄は "value or behavior — VERIFIED" という file:line + 値の明示を要求する。「コードを読まないと埋まらない」要求であり受動的記録とは異なる |
| #9 メタ認知チェックは機能しない | 自己評価ではなく外部的証拠の記述 |
| #10 判別力のないゲート | Divergence 欄の条件（"identical at every traced point"）は EQUIV 偽陽性の失敗モード（「コード差異はあるが値は同じ」）を直接弁別する。BL-10（「テストが到達するか」= 常に YES）とは判別力が異なる |

---

## 6. 変更規模

- 変更行数: fail-to-pass ブロック +10/-6、pass-to-pass ブロック +7/-5  
- 合計: ~17 行の置き換え（追加 10 行、削除 11 行）
- 変更外: Guardrails、Step 3–5.5、localize/explain/audit-improve、COUNTEREXAMPLE 節すべて無変更  
- 研究コア構造（番号付き前提 / 仮説駆動探索 / 手続き間トレース / 必須反証）: 維持
