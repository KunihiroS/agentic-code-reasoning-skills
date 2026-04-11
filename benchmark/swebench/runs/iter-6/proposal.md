# Iteration 6（再提案）— 改善案

## 1. 選択した Exploration Framework カテゴリ

**カテゴリ D: メタ認知・自己チェックの強化**

### 選択理由

前回提案（COMPARE HYPOTHESIS）は原則 #7（分析前の中間ラベル生成はアンカリングバイアスを導入する）に抵触するとして却下された。監査役のフィードバックにより、持続的失敗 3 件（15368, 13821, 15382）の共通パターンは「コード差異を発見した後、テストを通じた具体的なトレースなしに NOT_EQ と結論する」ことであると確認された。問題の本質は**方向予測の欠如ではなく、トレースの欠如**である。

カテゴリ D は BL-1〜BL-8 において直接的に試みられていないカテゴリである。

| BL番号 | カテゴリ対応 | 本質 |
|--------|------------|------|
| BL-1   | C (除外ルール) | 比較対象の定義変更 |
| BL-2   | A/D (閾値操作) | NOT_EQ 証拠閾値引き上げ |
| BL-3   | E (出力制約) | UNKNOWN 禁止 |
| BL-4   | A (探索削減) | 早期打ち切り |
| BL-5   | B (テンプレート形式) | P3/P4 記録形式規定 |
| BL-6   | A (既存制約拡張) | Guardrail 両方向化 |
| BL-7   | D* (中間ラベル) | 変更性質の事前分類（アンカリング失敗） |
| BL-8   | F (記録列追加) | localize の列移植（受動的記録） |

BL-7 はカテゴリ D の試みだが、失敗理由は「分析前のラベル生成によるアンカリング」（原則 #7）であり、**分析中**の自己チェックは試されていない。BL-2/BL-6 はカテゴリ A の「閾値操作」であり、「メタ認知的な自己チェック」とは根本的に異なるメカニズムである。

---

## 2. 改善仮説（1 つ）

**Compare 証明書テンプレートの ANALYSIS OF TEST BEHAVIOR 内、各テストの `Comparison:` 行の直後に 1 行の自己チェックを追加することで、AI が「実際にトレースしたか、それともコード構造から推論しただけか」をメタ認知的に確認させる。これにより、INFERRED と自己評価したケースで追加トレースの動機が生まれ、トレースなしの NOT_EQ 結論を防ぐ。**

### 根拠

持続的失敗 3 件（15368, 13821, 15382）はすべて EQUIV なのに NOT_EQ と結論するケースである。これらの共通パターン：

- コード差異を発見する
- その差異が「テスト結果に影響を与えるはずだ」とコード構造から推論する（INFERRED）
- 具体的なテスト入力を差異のあるコードパスに通してトレースしない
- NOT_EQ と結論する

既存の Guardrail 4（「差異がないと結論する前に trace せよ」）は EQUIV 方向をカバーしているが、コード構造を見て NOT_EQ と推論ジャンプするケースには直接作用しない。自己チェックにより、AI が自分のトレース行為の有無を明示的に評価することで：

1. INFERRED と記入した場合、AI 自身がトレース不足に気づき追加探索を行う動機が生まれる（原則 #8「能動的検証の誘発」に合致）
2. TRACED と記入する場合は既存のトレース行為を強化・意識化させる
3. EQUIV / NOT_EQ **両方向に完全に対称**である（原則 #1, #6 非該当）

**各失敗ケースとの関連：**

- **15368**: テスト削除を発見 → INFERRED で自己評価 → 「削除されたテストは実行されないため outcome が ABSENT であり DIFFERENT とは言えない」という再考が促される
- **13821**: pass-to-pass テストの code path 差異を発見 → INFERRED で自己評価 → 「テスト入力を差異のある code path に通してトレースしていない」と気づき追加トレースを行う
- **15382**: exception-in-loop の推論誤り → INFERRED で自己評価 → 「具体的な入力を通したトレースをしていない」と気づき再トレースで誤りを発見できる可能性がある

---

## 3. SKILL.md のどこをどう変えるか

### 変更箇所

**Compare モードの Certificate template 内、`ANALYSIS OF TEST BEHAVIOR:` ブロックの各テスト分析セクション、`Comparison: SAME / DIFFERENT outcome` の直後に `Trace check:` 行を 1 行追加する。**

既存内容への変更は最小限（`Comparison:` 行の後に 1 行追加するのみ）。

### 変更前（fail-to-pass tests の分析ブロック）

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
  Trace check: [TRACED / INFERRED] — Did I trace a concrete test input
               through the differing code path, or infer from code structure alone?
               If INFERRED, trace before proceeding.
```

pass-to-pass tests の分析ブロックにも同様に 1 行追加する：

### 変更前（pass-to-pass tests の分析ブロック）

```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後

```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  Comparison: SAME / DIFFERENT outcome
  Trace check: [TRACED / INFERRED] — Did I trace a concrete test input
               through the differing code path, or infer from code structure alone?
               If INFERRED, trace before proceeding.
```

### 変更規模

- **追加行数: 3 行 × 2 箇所 = 計 6 行**（20 行目安に余裕あり）
- **削除・変更行数: 0 行**（既存内容不変）
- **影響範囲**: Compare モードの certificate template のみ
- **他モード（localize, explain, audit-improve）、Step 3〜5.5、Guardrails への影響**: なし

---

## 4. EQUIV / NOT_EQ 両正答率への影響予測

| 方向 | 予測 | 理由 |
|------|------|------|
| **EQUIV 正答率**（現 70%） | **+5〜10pp 改善** | INFERRED と自己評価した場合に追加トレースを促すことで、コード差異からの推論ジャンプによる NOT_EQ 誤判定が減少する。持続的失敗 3 件はいずれもトレース不足の NOT_EQ 誤判定であり、このチェックが直接作用する |
| **NOT_EQ 正答率**（現 100%） | **±0〜+3pp** | 真の NOT_EQ ケースでは差異のある code path をトレースすれば TRACED と自己評価でき、追加コストは発生しない。むしろ TRACED の確認がトレースの質を意識化させ、浅い NOT_EQ 結論を防ぐ効果もある |
| **全体** | **+3〜8pp** | 主として EQUIV 誤判定の修正。NOT_EQ 正答率への悪影響は最小限 |

### 判定方向の対称性確認

Trace check は EQUIV / NOT_EQ いずれの方向の分析にも同様に適用される。NOT_EQ を難しくするのではなく、**トレースの有無という中立的な行為の自己確認**を求めるため、原則 #1（判定の非対称操作）に抵触しない。

---

## 5. failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL番号 | 内容 | 本提案との差異 |
|--------|------|--------------|
| **BL-1** | ABSENT 定義追加 | **非重複**。テストの除外定義を追加しない |
| **BL-2** | NOT_EQ 証拠閾値強化・call path 明示要求 | **異なるメカニズム**。BL-2 は COUNTEREXAMPLE ブロックへの trace 要求（出力への制約）。本提案は分析中の自己チェックであり、NOT_EQ の閾値を上げるのではなくトレース行為の自己認識を促す |
| **BL-3** | UNKNOWN 禁止 | **非重複**。出力の制約をしない |
| **BL-4** | 早期打ち切り | **非重複**。探索を削減しない |
| **BL-5** | P3/P4 記録形式規定 | **非重複**。前提収集の形式を変えない |
| **BL-6** | Guardrail 両方向化 | **異なる作用点**。BL-6 は既存 Guardrail の両方向拡張（実質 NOT_EQ 制約）。本提案は分析テンプレート内の自己チェックであり、Guardrail への変更なし |
| **BL-7** | CHANGE CHARACTERIZATION（分析前の性質ラベル） | **根本的に異なる**。BL-7 は分析「前」に変更性質を分類させ（アンカリング発生）、本提案は分析「中」にトレース行為の有無を確認させる。ラベルは判定方向に相関しないため原則 #7 非該当 |
| **BL-8** | `Relevant to` 列追加（受動的記録） | **異なるメカニズム**。BL-8 は「関係性を記録する列」の追加（受動的記録）。本提案は「自分がトレースしたかどうか」の自己チェックであり、INFERRED 時に能動的な追加探索を直接促す（原則 #8 の対偶） |

### 共通原則照合結果

| 原則 | 判定 | 理由 |
|------|------|------|
| #1 判定の非対称操作 | ✅ 非該当 | EQUIV / NOT_EQ 両方向の分析に完全に対称適用。トレースの有無は判定方向に非依存 |
| #2 出力側の制約 | ✅ 非該当 | 出力への制約ではなく、分析プロセス内の自己チェック |
| #3 探索量の削減 | ✅ 非該当 | 探索を増やす方向（INFERRED 時に追加トレースを促す） |
| #4 同方向の変更 | ✅ 非該当 | BL-2/BL-6 とは効果の方向が異なる。本提案は NOT_EQ の立証責任を引き上げるのではなく、トレース行為の有無を問う |
| #5 入力テンプレートの過剰規定 | ✅ 非該当 | 記録形式を規定しない。自己チェックは [TRACED / INFERRED] の二択のみ |
| #6 対称化の実効差分 | ✅ 非該当 | 差分は対称（両方向のテスト分析ブロックに同一の 1 行を追加） |
| **#7 中間ラベル生成のアンカリング** | ✅ **非該当** | 分析「中」の自己チェックであり、分析「前」の方向ラベル生成ではない。[TRACED / INFERRED] は判定方向（EQUIV / NOT_EQ）と直接相関しない行為ラベルであり、アンカリング効果は生じない |
| **#8 受動的な記録フィールドの追加** | ✅ **非該当** | [INFERRED] と記入した際に「trace before proceeding」という明示的な行動指示が付く。これは受動的な記録ではなく、能動的な再探索を直接誘発する仕組みである |

**すべての原則に対して非該当であることを確認した。**

---

## 6. 監査役の代替提案との整合性

監査役の代替提案（フィードバック §6「代替提案」）を直接実装したものが本提案である。

監査役提案：
> **ANALYSIS OF TEST BEHAVIOR の各テスト分析内の Comparison 行直後に、1行の自己チェックを追加**
> ```
>   Comparison: SAME / DIFFERENT outcome
>   Trace check: Did I trace a concrete test input through the differing code path, or did I infer the outcome from the code structure alone? [TRACED / INFERRED]
> ```

本提案との差分：
- 監査役提案の内容をそのまま採用
- INFERRED の場合に「trace before proceeding」の行動指示を明示的に付加（より強い能動的検証の誘発）
- fail-to-pass / pass-to-pass 両ブロックに適用（一貫性のため）

---

## 7. 全体の推論品質への期待

持続的失敗 3 件の根本原因は「コード差異を発見した後、テストを通じた具体的なトレースなしに NOT_EQ と結論する」ことである。Trace check はこのプロセスの最も弱いリンクに直接作用する：

- **AI は Comparison を記入した直後に自分のトレース行為を自己評価しなければならない**
- **INFERRED と判断すれば「trace before proceeding」という指示が直接作用する**
- **このチェックは分析の外側ではなく内側に組み込まれているため、スキップされにくい**

原則 #8 の教訓（「受動的な記録は能動的な検証を誘発しない」）を反転させ、**自己チェックが能動的な再探索を直接誘発する設計**としている点が BL-8 との本質的な違いである。
