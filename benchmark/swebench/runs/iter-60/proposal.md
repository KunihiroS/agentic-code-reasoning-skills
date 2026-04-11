# Iteration 60 — 改善案提案

## 親イテレーション (iter-56) の選定理由

指示通り iter-56（スコア 70%, 14/20）を親として選択する。

iter-56 のスコアは iter-35（85%, 17/20）から大幅に後退した。差分を分析すると、iter-56 は2つの変更を加えた:

1. **D2(b) に 2 行追加**: `Verify this by tracing the test's execution; do not assume relevance from file proximity, shared module, or test-level changes such as deletion.`
2. **チェックリスト item 6 の文言変更**: `changes the PASS/FAIL result of at least one relevant test, not merely the internal execution path`

この2変更の効果を iter-35 との比較で分析する:

| ケース | iter-35 | iter-56 | 変化 |
|--------|---------|---------|------|
| 13821 (EQUIV) | NOT_EQ ✗ | EQUIV ✓ | **改善** (チェックリスト変更が効果) |
| 11179 (EQUIV) | EQUIV ✓ | NOT_EQ ✗ | **回帰** |
| 15382 (EQUIV) | EQUIV ✓ | NOT_EQ ✗ | **回帰** |
| 14787 (NOT_EQ) | NOT_EQ ✓ | UNKNOWN ✗ | **回帰** |
| 14122 (NOT_EQ) | NOT_EQ ✓ | UNKNOWN ✗ | **回帰** |
| 12663 (NOT_EQ) | NOT_EQ ✓ | UNKNOWN ✗ | **回帰** |

差し引き: +1改善 -5回帰 = 85% → 70%。

D2(b) の2行追加は failed-approaches.md の **BL-22**（iter-47 で試行）と**同一の変更**である（"do not assume relevance from file proximity, shared module, or test-level changes such as deletion"）。BL-22 は「NOT_EQ 側の正答ケースが UNKNOWN / EQUIV に落ちる大規模回帰」を引き起こしており、iter-56 はこれを再試行した形となっている。

したがって iter-60 の最優先課題は **BL-22 等価の D2(b) 追加の除去**であり、iter-56 が問題の原因を内包しているため、そこを親として選定する必要がある。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ B: 情報の取得方法を改善する**

> 何を探すかではなく、どう探すかを改善する

### 選択理由

iter-56 は**カテゴリ E（表現・フォーマットの改善）**を使用した。今回はカテゴリ E 以外から選択する必要があるため、カテゴリ B を選択する。

カテゴリ B の選択根拠:

- D2(b) の追加変更は「pass-to-pass テストの関連性をどう判定するか」という情報取得方法（Category B）に属する変更であった。その過剰規定（トレース義務の追加）を削除することは、情報取得方法の改善（過剰な探索コストの除去）に当たる
- BL-22 の Fail Core は「ネガティブプロンプトによる禁止は過剰適応を招く（原則 #16）」であり、その禁止句を削除することは原則 #16 に沿った修正である
- カテゴリ B の他の失敗 BL 項目（BL-5, 8, 12, 13, 17, 18, 20, 23, 28）はいずれも**追加**的な規定の失敗であり、**削除**による修正はいずれとも異なるメカニズムである
- カテゴリ A（BL-4, 12, 14, 21）、C（BL-7, 11, 19）、D（BL-9, 10）、F（BL-24〜28 等）はすべてより多くの BL 項目が蓄積しており、安全な余地が少ない

---

## 改善仮説（1つ）

**iter-56 が D2(b) に追加した 2 行（BL-22 等価）は、pass-to-pass テストの関連性を確認するために「テスト実行のトレース」を義務付ける過剰規定であり、NOT_EQ ケースでのターン枯渇（31 ターン上限による UNKNOWN）を直接引き起こしている。この 2 行を削除することで、ターン枯渇 UNKNOWN が解消し、スコアが 70% → 80〜85% 程度に回復する。**

根拠:

1. **BL-22 との完全な等価性**: iter-56 の D2(b) 追加は iter-47（BL-22）と事実上同じ変更である。BL-22 は "NOT_EQ 側の正答ケース（14787 など）が EQUIV に落ちる回帰" を引き起こした（iter-47 では EQUIV、iter-56 では UNKNOWN という形の違いがあるが、チェックリスト変更との複合効果と考えられる）

2. **UNKNOWN 4件のターン消費パターン**: iter-56 の UNKNOWN ケース（15368, 14787, 14122, 12663）はすべて 31 ターンに到達しており、ターン枯渇が共通原因である。「テスト実行をトレースして関連性を確認せよ」という義務が各 pass-to-pass テストに対して高コストな探索を要求し、本来 NOT_EQ の差分に到達する前にターン予算を消耗させる

3. **チェックリスト変更（item 6）の保持**: iter-56 のもう一方の変更（"not merely the internal execution path"）は 13821 の改善に効いている（iter-35 では NOT_EQ だった 13821 が iter-56 では EQUIV 正答）。この変更は保持することで 13821 の正答を維持する

4. **原則 #16 との整合**: 「ネガティブプロンプト（do not assume relevance from...）は過剰適応を招く」という共通原則 #16 に基づくと、この禁止句を削除することは推論品質を改善する方向の変更である

---

## SKILL.md のどこをどう変えるか

### 変更対象

`## Compare` セクションの `### Certificate template` 内 `DEFINITIONS > D2(b)` ブロック。

### 変更前（現在の SKILL.md, iter-56 状態）

```
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
        Verify this by tracing the test's execution; do not assume relevance
        from file proximity, shared module, or test-level changes such as deletion.
    To identify them: search for tests referencing the changed function, class,
```

### 変更後（提案）

```
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
    To identify them: search for tests referencing the changed function, class,
```

### 変更内容の説明

D2(b) から「`Verify this by tracing the test's execution; do not assume relevance from file proximity, shared module, or test-level changes such as deletion.`」の 2 行を削除する。

- **新規追加行数: 0 行**（削除のみ）
- 削除後の D2(b) は iter-35 以前の状態に戻り、テストの関連性判定に余分なトレース義務を課さない
- チェックリスト item 6 の変更（"not merely the internal execution path"）は保持する

---

## EQUIV と NOT_EQ の両方の正答率にどう影響するかの予測

### NOT_EQ（現在: 6/10 = 60%）→ 改善予測

iter-56 での NOT_EQ UNKNOWN ケース（14787, 14122, 12663）はすべて BL-22 等価追加によるターン枯渇が原因と考えられる。削除後は iter-35 時点（9/10〜10/10）相当に回復する可能性が高い。

- 14787, 14122, 12663: NOT_EQ UNKNOWN → NOT_EQ ✓ に回復（予測）
- 11433: iter-35 でも UNKNOWN 失敗ケース。本変更の対象外であり改善は見込まない

予測: 6/10 → 9/10（+3件）

### EQUIV（現在: 7/10 = 70%）→ 微改善または横ばい予測

- 11179, 15382: これらの NOT_EQ 誤判定は、チェックリスト変更（"not merely the internal execution path"）または D2(b) 追加の複合効果の可能性がある。D2(b) のみ削除した場合、改善するかは不明だが、少なくとも「トレース義務による探索過多」が解消されることで挙動が変わる可能性がある
- 13821: チェックリスト変更を保持するため、iter-56 での正答は維持（predicted=EQUIV）
- 15368: ターン枯渇の解消により UNKNOWN → NOT_EQ または EQUIV へ変化する可能性があるが、15368 は難しいケースであるため予測は控える

予測: 7/10 維持（最良ケース 8〜9/10）

### 総合予測

現在 14/20（70%）→ 16〜17/20（80〜85%）

---

## failed-approaches.md ブラックリストおよび共通原則との照合結果

### ブラックリスト照合

| BL 項目 | 類似度 | 判定 | 理由 |
|---------|--------|------|------|
| BL-22: D2(b) へのネガティブプロンプト追加 | 本変更はその**削除** | 非該当（修正行為） | BL-22 の Fail Core が指摘する「ネガティブプロンプトは過剰適応を招く」に基づく**修正**であり、BL-22 の繰り返しではない |
| BL-1: テスト除外定義の追加 | 低 | 非該当 | 本変更は定義の追加ではなく、過剰規定の削除 |
| BL-2: NOT_EQ 証拠閾値の引き上げ | 低 | 非該当 | 本変更は証拠要件を変更せず、探索コストを下げるのみ |
| BL-3: UNKNOWN 回答の禁止 | 低 | 非該当 | 本変更は結論の制約ではなく、探索コストの削減 |
| BL-4, BL-10: 条件分岐ゲート | 低 | 非該当 | ゲートの追加ではなく削除 |
| BL-14: アドバイザリな非対称指示 | 低 | 非該当 | 本変更は非対称指示の削除であり、追加ではない |
| BL-17: 探索対象の外側拡張 | 低 | 非該当 | 探索範囲の変更ではなく、トレース義務の削除 |

### 共通原則との照合

| 共通原則 | 評価 |
|----------|------|
| #1: 判定の非対称操作は必ず失敗する | 本変更は NOT_EQ / EQUIV いずれかに有利な制約を追加しない。削除するのは特定方向への立証ハードルを上げていた禁止句であり、削除後は対称性が改善する ✓ |
| #2: 出力側の制約は効果がない | 本変更は出力制約ではなく、入力側（探索方法）の過剰規定の削除 ✓ |
| #3: 探索量の削減は常に有害 | 「有効な探索の削減」ではなく「空振りコストの削減」である。D2(b) のトレース義務は関連性を確認する overhead であり、NOT_EQ 差分へのアクセスを妨げていた。この整理は原則 #3 の「情報不足が誤判定の主因」とは相反しない（ターン枯渇による UNKNOWN は情報取得の失敗ではなく、探索コスト超過による早期打ち切り） △（ただし他の削減と異なり空振りコストの削減であるため許容範囲と判断） |
| #5: 入力テンプレートの過剰規定は探索視野を狭める | 本変更は過剰規定の削除であり、この原則を支持する変更 ✓ |
| #14: 条件付き特例探索を足しても主ループを強化しなければ全体性能は下がる | 本変更はその逆（特例探索の除去によって主ループ実行のターン余裕を回復させる）✓ |
| #16: ネガティブプロンプトによる禁止は過剰適応を招く | 本変更は禁止句（"do not assume relevance from..."）を削除するものであり、この原則の処方箋そのものである ✓ |
| 特定ケースの狙い撃ち | 本変更は特定ケース ID を参照しない。BL-22 等価という共通の失敗パターンに基づく汎用的な修正 ✓ |

### 共通原則 #3 のリスク評価（詳細）

「探索量の削減は常に有害」という原則は BL-4（CONVERGENCE GATE: 最大読取ファイル数制限）等の「情報収集そのものを制限する変更」に適用される。本変更が削除するのは「pass-to-pass テストの関連性を確認するために、その実行をトレースせよ」という高コスト検証義務であり、これは NOT_EQ の証拠収集を直接担うものではない。エージェントは既に D2(b) の「search for tests referencing the changed function, class, or variable」という検索義務でテストの候補を網羅的に探索できる。削除した 2 行は「候補を見つける」段階ではなく「候補が relevant かを個別にトレース検証する」という二重確認ステップであり、主探索ループの情報量を減らすものではない。

---

## 変更規模の宣言

- **新規追加行数: 0 行**（hard limit 5 行以内を大きく下回る。削除のみ）
- **削除行数: 2 行**（D2(b) のトレース義務句の 2 行）
- **変更対象**: `## Compare > ### Certificate template > DEFINITIONS > D2(b)` の 2 行削除のみ
- **変更規模**: 最小（2 行削除、追加なし）
