# Iteration 10 — 改善案（Proposal）

## 前イテレーション（iter-9）の分析

### スコアサマリー

- iter-9 スコア: 80%（16/20）
- EQUIV 正答率: 7/10（70%） — 15368, 13821, 15382 が誤（NOT_EQUIVALENT と誤判定）
- NOT_EQ 正答率: 9/10（90%） — 14787 が誤（EQUIVALENT と誤判定）

### 失敗パターン分析

**パターン A（EQUIV 偽陽性 × 3）**: 15368・13821・15382 は引き続き NOT_EQUIVALENT と誤判定。
iter-9 の Propagation check（乖離点 → アサーション到達の確認）が加わっているにもかかわらず、
エージェントはコードパス上の乖離を発見し「伝播する」と結論付ける。

考えられる原因: Propagation check では「この乖離はテストアサーションに到達するか?」と問うが、
アサーションの具体的な内容（何を、どのファイルの何行目で検査しているか）を
エージェントが事前に把握していないため、「到達する」の判断が表面的な
コールパス有無の確認（BL-10 的な形式的通過）で終わっている可能性がある。
Propagation の先に何があるかを知らずにトレースしているため、
「どこかの assertion に値が届く」という曖昧な答えで DIFFERENT 結論に至っている。

**パターン B（NOT_EQ 偽陰性 × 1）**: 14787 は EQUIVALENT と誤判定。
NOT_EQ だが、エージェントが実際の差異箇所を特定できていない可能性がある。
アサーション箇所が何を検査しているかを把握した上でトレースすれば、
差異がアサーションに影響することを検出しやすくなるかもしれない。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ B: 情報の取得方法を改善する**

### 選択理由

カテゴリ B はこれまで BL-5（P3/P4 の形式を PREMISES に記録）で一度試みられたが、
PREMISES への記録（分析開始前の抽象的な記述）と、**分析中・テスト単位での具体的な
ファイル参照**とでは根本的にメカニズムが異なる。

iter-6〜9 で試みたカテゴリ（D, A, F, F）の共通点は「乖離発見後に検証ステップを追加する」
アプローチである。これに対し、カテゴリ B の「探索の優先順位付けを変える」は
**乖離を探すより先にアサーションを読む**という順序の変化であり、
これまで明示的に試みられていない。

BL-5 との違い:
- BL-5: PREMISES（P3/P4）に「テストが何を検査するか」を抽象記述する形式変更
- 本提案: ANALYSIS OF TEST BEHAVIOR の **各テストブロック内** に `Assertion:` 行を追加し、
  テスト分析を開始する前に **そのテストのアサーション（file:line）を実際に読む** ことを義務化
- 場所・粒度・タイミングが異なる: PREMISES（全体前提）ではなく、per-test の分析ステップ内

---

## 改善仮説（1つ）

**compare モードの ANALYSIS OF TEST BEHAVIOR における各テストブロックの冒頭に
`Assertion:` アンカー行（file:line 引用必須）を追加することで、
エージェントが Divergence/Propagation 分析を始める前にそのテストが
「何を、どこで検査しているか」を把握させ、Propagation check の伝播判断を
具体的なアサーション条件に照らした検証として機能させる。
これにより EQUIV 偽陽性（コードレベルの乖離が「何らかのアサーションに到達する」という
曖昧なトレースで DIFFERENT 結論になること）を防ぎ、NOT_EQ ケースでは
アサーションに何が影響するかを把握したうえで差異を探せるようにする。**

根拠:
- Propagation check（iter-9）が「アサーションに到達するか」を問うが、
  エージェントが「アサーションが何を検査しているか」を先に把握していなければ、
  到達判定がコールパスの有無（BL-10 と同様の形式的通過）で終わる。
  Assertion アンカーは Propagation check の前提情報を充実させる。
- BL-8 共通原則 #8「受動的記録は能動的検証を誘発しない」への対応:
  `Assertion: [file:line]` は「実際にテストファイルを開いて読む」行動（能動的検証）を
  誘発する。file:line 引用を要求することで、読まずに埋めることができない。
- BL-10 共通原則 #10「ゲートは判別力を持つ条件が必要」への対応:
  Assertion アンカーは条件分岐ゲートではなく、後続の Propagation 判断に使われる
  **参照情報の収集ステップ**であり、BL-10 の構造的問題と異なる。
- 共通原則 #3「探索量削減は有害」: テストファイルを実際に読む分、探索量は増える方向。

---

## SKILL.md のどこをどう変えるか

### 変更箇所

compare モードの Certificate template 内、`ANALYSIS OF TEST BEHAVIOR` セクション:

- **fail-to-pass テストブロック**: `Test: [name]` 行と `Divergence:` 行の間に
  `Assertion:` アンカー行を 1 行追加
- **pass-to-pass テストブロック**: 同様に `Test: [name]` と `Divergence:` の間に
  `Assertion:` アンカー行を 1 行追加

### 変更前（fail-to-pass ブロック）

```
For each relevant test:
  Test: [name]
  Divergence: Identify the first point in this test's code path where
              Change A and Change B produce different values or behavior.
    A at [file:line]: [specific value or behavior — VERIFIED by reading source]
    B at [file:line]: [specific value or behavior — VERIFIED by reading source]
    Propagation: Does this divergence reach the test assertion?
      Trace from divergence point to the test assertion that would detect this difference.
      If no assertion receives a changed value: Comparison is SAME.
    (If values are identical at every traced point through the test assertion:
     Comparison is SAME — omit Claim below)
  Claim C[N]: Test will [PASS with A / FAIL with B] or [FAIL with A / PASS with B]
              because [trace from divergence point to test assertion — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後（fail-to-pass ブロック）

```
For each relevant test:
  Test: [name]
  Assertion: [read this test file — cite file:line — what exact value or condition is asserted]
  Divergence: Identify the first point in this test's code path where
              Change A and Change B produce different values or behavior.
    A at [file:line]: [specific value or behavior — VERIFIED by reading source]
    B at [file:line]: [specific value or behavior — VERIFIED by reading source]
    Propagation: Does this divergence reach the test assertion?
      Trace from divergence point to the test assertion that would detect this difference.
      If no assertion receives a changed value: Comparison is SAME.
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
  Divergence: Where in this test's code path do A and B produce different values?
    A at [file:line]: [value or behavior — VERIFIED]
    B at [file:line]: [value or behavior — VERIFIED]
    Propagation: Does this divergence reach the test assertion?
      Trace from divergence point to the test assertion that would detect this difference.
      If no assertion receives a changed value: Comparison is SAME.
    (If identical at every traced point: Comparison is SAME — omit Claim below)
  Claim C[N]: behavior differs because [trace from divergence to assertion — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後（pass-to-pass ブロック）

```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Assertion: [read this test file — cite file:line — what exact value or condition is asserted]
  Divergence: Where in this test's code path do A and B produce different values?
    A at [file:line]: [value or behavior — VERIFIED]
    B at [file:line]: [value or behavior — VERIFIED]
    Propagation: Does this divergence reach the test assertion?
      Trace from divergence point to the test assertion that would detect this difference.
      If no assertion receives a changed value: Comparison is SAME.
    (If identical at every traced point: Comparison is SAME — omit Claim below)
  Claim C[N]: behavior differs because [trace from divergence to assertion — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更規模

- 追加: 2 行（fail-to-pass ブロック 1 行 + pass-to-pass ブロック 1 行）
- 削除: 0 行
- 変更対象: compare モード Certificate template のみ
- 他モード（localize, explain, audit-improve）、Guardrails、Core Method は変更なし
- **20 行以内の目安を大幅に下回る（2 行）**

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV（現状 7/10 = 70%）

**改善予測: 7/10 → 9〜10/10**

- 15368, 13821, 15382（偽陽性 3 件）: Assertion アンカーにより、
  エージェントがテストの「何を検査しているか」を把握した状態で Propagation を実施する。
  コードレベルの乖離が発見されても、それがアサーションの検査対象に影響しない場合、
  Propagation で「No — assertion at [file:line] checks [condition], divergence changes [other thing]」
  と明示されやすくなり、Comparison は SAME となる。
  乖離の「どこかのアサーションに届く」という曖昧な肯定が排除される。
- 正答中 7 件: Assertion アンカーの記入（1 ターン程度の追加）はあるが、
  乖離が存在しない（または既にアサーションまで正確にトレース済み）の構造は変わらず、
  回帰リスクは低い。

### NOT_EQ（現状 9/10 = 90%）

**予測: 9/10 → 9〜10/10**（改善または現状維持）

- 14787（偽陰性 1 件）: Assertion アンカーによりアサーション箇所を先に把握することで、
  「どのパスを重点的にトレースすべきか」の焦点が明確化し、差異の検出を助ける可能性がある。
  ただし改善幅は不確実。
- 正答中 9 件: Assertion アンカーはわずかなターン追加になるが、
  真の NOT_EQ 差異は Propagation で確認可能であり、大きな影響はない。
  回帰リスクは低い。

---

## failed-approaches.md のブラックリストおよび共通原則との照合結果

| 項目 | 照合結果 | 根拠 |
|------|----------|------|
| BL-1（ABSENT 定義追加） | 非該当 | テスト除外ルールを導入しない |
| BL-2（NOT_EQ 証拠閾値強化） | 非該当 | DIFFERENT 結論の立証責任を引き上げない。Assertion アンカーは参照情報の追加であり、証拠閾値の変更ではない |
| BL-3（UNKNOWN 禁止） | 非該当 | 出力制約を追加しない |
| BL-4（CONVERGENCE GATE） | 非該当 | 早期打ち切りを導入しない |
| BL-5（P3/P4 形式強化） | **類似性あり・異なるメカニズム** | BL-5 は PREMISES（全体前提）への記録。本提案は per-test の ANALYSIS ブロック内・分析開始直前・file:line 引用必須という点で場所・粒度・タイミングが本質的に異なる |
| BL-6（Guardrail 4 対称化） | 非該当 | 既存制約の対称拡張ではなく新規追加 |
| BL-7（CHANGE CHARACTERIZATION） | 非該当 | 分析前の変更性質ラベル生成を行わない |
| BL-8（受動的記録列追加） | **PASS** | `Assertion: [file:line]` は「テストファイルを実際に読む」能動的行動を誘発する（file:line がなければ記入できない）。受動的な記述フィールドとは異なる |
| BL-9（メタ認知チェック） | 非該当 | 自己評価チェックを追加しない |
| BL-10（Reachability ゲート） | 非該当 | YES/NO 条件分岐ゲートを追加しない。Assertion は Propagation の参照情報であり、スキップ条件ではない |
| 共通原則 #1（非対称操作） | **PASS** | EQUIV・NOT_EQ どちらの判定方向にも同一形式を適用。判定閾値を移動させない |
| 共通原則 #2（出力制約排除） | **PASS** | ANALYSIS ステップの追加であり、出力形式・判定フォーマットの制約ではない |
| 共通原則 #3（探索量削減禁止） | **PASS** | テストファイルを読む探索量を増やす方向 |
| 共通原則 #4（同方向再試禁止） | **PASS** | BL-5 と同カテゴリだが場所・タイミング・メカニズムが異なる。「分析前の PREMISES 記録」ではなく「分析中の per-test アンカー」 |
| 共通原則 #5（過剰規定回避） | **PASS** | 1 行追加のみ。Assertion の記述内容を詳細に規定しない（何の値/条件かを記すだけ） |
| 共通原則 #6（対称化差分） | **PASS** | 既存制約の拡張ではなく新規追加。差分は EQUIV・NOT_EQ 双方に対称 |
| 共通原則 #7（中間ラベル禁止） | **PASS** | Assertion の記録はテストが何を検査するかという事実であり、EQUIV/NOT_EQ への判定方向と相関するラベル（変更の性質分類等）ではない |
| 共通原則 #8（受動的記録） | **PASS** | file:line 引用がなければ記入できない形式であり、能動的なファイル読み取りを必要とする |
| 共通原則 #9（メタ認知限界） | **PASS** | 自己チェックではなく外部証拠（テストファイル）の読み取りを要求する |
| 共通原則 #10（ゲート判別力） | **PASS** | ゲートではなく参照情報収集ステップ |

---

## 変更規模

- 追加行数: **2 行**（fail-to-pass ブロック 1 行 + pass-to-pass ブロック 1 行）
- 削除行数: 0 行
- 20 行以内の目安を満たす（2 行）
