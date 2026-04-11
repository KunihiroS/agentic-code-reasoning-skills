# Iteration 48 — 改善案提案

## 1. 親イテレーション (iter-29) の選定理由

iter-29 (スコア 75%、15/20) は以下の理由で親として選定された:

- iter-28 で追加した `COUNTEREXAMPLE` ブロックの `By P[N]` フィールドが NOT_EQ 立証ハードルを非対称に上げたため、iter-29 はその削除（リバート）でスコアを 75% 水準に戻したクリーンなベースライン
- iter-28 の変更（BL-15 として登録済み）が除去され、探索空間がリセットされている
- 同じベースから出発した後続イテレーション（iter-41）が Category B アプローチで 85%（17/20）を達成した実績があり、再現可能な改善余地が確認されている

---

## 2. 選択した Exploration Framework カテゴリとその理由

**カテゴリ B: 情報の取得方法を改善する**
> 「何を探すかではなく、どう探すか・何を確認してから判断するかを改善する」

### 選定理由

iter-29 基点での各カテゴリ試行状況を整理すると:

| カテゴリ | 最高スコア（iter-29 基点） | 代表イテレーション |
|---------|--------------------------|-----------------|
| A | 70%（14/20）| iter-45 |
| B | **85%（17/20）** | iter-41 ✓ |
| C | 75%（15/20）| iter-34/35 |
| D | 実質 BL-9 でブラックリスト化 | iter-9 等 |
| E | 75%（15/20）| iter-30/47 |
| F | 65%（13/20）以下 | iter-38〜43 等 |

カテゴリ B の iter-41 実装が唯一 85% を達成し、その変更が iter-29 の SKILL.md に直接適用可能（対象行が現 SKILL.md に存在）であることを確認した。他のカテゴリは BL 登録済みか改善実績がない。

---

## 3. 改善仮説（1つ）

**「Compare checklist の既存行『When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact』が曖昧であるため、エージェントは変更関数のコードを読んだ時点でその義務を満たしたと解釈し、吸収確認を省略したまま NOT_EQ を結論する。この行を『変更関数で差分を発見したら、すでにトレース済みの relevant test call path 上の直近の consumer 関数を読み、差分が伝播するか吸収されるかを記録してから Claim を確定せよ』という方向性を明示した形に精緻化することで、EQUIV 偽陰性（15368, 13821）を修正できる。」**

### 失敗パターンの分析

iter-29 の失敗ケース（15368, 13821, 15382）はすべて EQUIV を NOT_EQ と誤判定している。

15368 と 13821 の共通パターン:
1. エージェントが変更関数のコード差分を発見する（Step 3/4）
2. 「X が異なる値を返す」という Claim を書く
3. `Comparison: DIFFERENT` を記録する
4. 吸収される可能性を確認せず NOT_EQ を結論する

根本原因: 現行の checklist 行「trace at least one relevant test through the differing path」が「変更関数 X を読んだ（差分を見た）」時点で充足可能な曖昧な表現であり、X の呼び出し元（test call path の nearest consumer）で差分が正規化・吸収されるかを確認するよう誘導しない。

---

## 4. SKILL.md のどこをどう変えるか

### 変更箇所

`### Compare checklist` の 5 番目の bullet（SKILL.md line 220）を精緻化した表現に置換する。

### 変更前（現状: SKILL.md line 220）

```
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
```

### 変更後

```
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), do not stop tracing at that function: read the function on the already-traced relevant test call path that consumes the changed output, and record whether it propagates or absorbs the difference before assigning the Claim outcome.
```

### 変更の意図

- 「semantic difference」→「behavioral difference in a changed function」: 変更関数内での挙動差分に焦点を絞る
- 「trace at least one relevant test through the differing path」→「read the function on the already-traced relevant test call path that consumes the changed output」: すでにトレース済みの test call path 上の consumer 関数を読む方向性を明示する。新たな探索対象を定義するのではなく、既存のトレースを 1 ステップ延長する
- 「before concluding it has no impact」→「record whether it propagates or absorbs the difference before assigning the Claim outcome」: 差分の伝播/吸収を記録してから Claim を確定することを義務化する（NOT_EQ 方向への先走りを防ぐ）

---

## 5. EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV 正答率への影響（現在: 7/10 = 70%）

| ケース | 現状 | 予測 | 根拠 |
|--------|------|------|------|
| 15368（EQUIV → NOT_EQ 誤答） | 誤 | 改善可能 | 変更関数で差分発見後、nearest consumer を読む義務が明示され、吸収を発見すれば Claim を PASS に修正できる |
| 13821（EQUIV → NOT_EQ 誤答） | 誤 | 改善可能 | 同上 |
| 15382（EQUIV → NOT_EQ 誤答） | 誤 | 変化未定 | ターン数・コンフィグ依存の可能性あり。nearest consumer 確認が吸収発見に繋がれば改善するが、保証なし |
| 他 7 件（正答 EQUIV） | 正 | 維持 | nearest consumer を読んでも差分伝播が確認 → 既存正答を上書きしない |

**期待: +1〜+2（EQUIV 偽陰性が減少）**

### NOT_EQ 正答率への影響（現在: 8/10 = 80%）

| ケース | 現状 | 予測 | 根拠 |
|--------|------|------|------|
| 14787（NOT_EQ → EQUIV 誤答） | 誤 | 変化未定 | consumer 確認で差分伝播が確認されれば改善の余地あり |
| 12663（NOT_EQ → UNKNOWN）| 誤 | 変化なし | ターン枯渇が主因。consumer 確認の 1 ステップ追加はあるが、真 NOT_EQ では consumer が伝播を即確認 → ターン消費は最小 |
| 他 8 件（正答 NOT_EQ） | 正 | 維持 | 真 NOT_EQ では nearest consumer が差分を伝播 → Claim 補強 → 結論変わらず |

**期待: 維持（80%）または +1**

### 総合予測

| 現スコア | 期待スコア |
|---------|-----------|
| 75%（15/20）| 80〜85%（EQUIV +1〜+2）|

---

## 6. failed-approaches.md ブラックリストおよび共通原則との照合結果

### ブラックリスト照合

| BL # | 内容 | 本提案との関係 |
|------|------|--------------|
| BL-2 | NOT_EQ 証拠閾値の厳格化 | **非抵触**: verdict-conditioned ではない（「before asserting NOT_EQ」形式ではない）。差分発見時に consumer を読む行動は EQUIV / NOT_EQ 両方向に等しく作用する |
| BL-6 | 対称化（既存差分が片側に作用） | **非抵触**: 既存行の精緻化（置換）。変更前との差分は「nearest consumer on test path を読む」という方向指定で、verdict-conditioned でない |
| BL-8 | 受動的記録フィールド追加 | **非抵触**: フィールド追加なし。consumer 関数を実際に読む探索行動を直接要求する |
| BL-9 | メタ認知的自己チェック | **非抵触**: 自己評価ではなく「特定の関数を読む」という外部的に検証可能な行動を指示 |
| BL-14 | アドバイザリな非対称指示 | **非抵触**: 「DIFFERENT と主張する場合にのみ」という非対称条件なし。差分発見時に常時適用 |
| BL-15 | COUNTEREXAMPLE の By P[N] 削除 | **無関係**: Compare checklist の別行への変更 |
| BL-17 | caller/wrapper/helper へのスコープ拡張 | **非抵触**: 「already-traced relevant test call path 上の」consumer に限定。relevant test 集合を拡張しない |
| BL-21 | Observed が中間値なら 1 hop Guardrail 追加 | **概念類似だが機構が異なる**: BL-21 は Guardrail への追加 + 固定 "1 hop" 指定。本提案は Compare checklist 既存行の置換 + "nearest consumer on test call path"（hop 数ではなく意味論的定義）。Fail Core は「固定 hop 数が意味論的終点を保証しない」であり、本提案は hop 数ではなく「changed output を消費する関数」という意味論的定義を使う |
| BL-22 | D2(b) へのネガティブプロンプト | **無関係**: Compare checklist の変更。ネガティブプロンプトではなく探索行動の明示 |

### 共通原則照合

| 原則 | 本提案の評価 |
|------|------------|
| #1 判定の非対称操作 | **対称**: 差分発見時に常時発火。EQUIV では吸収確認、NOT_EQ では伝播確認として均等に作用 ✓ |
| #2 出力側の制約は効果なし | **探索プロセス側**: Claim 確定前の読取行動を指示（出力テンプレートの禁止/要求ではない） ✓ |
| #3 探索量の削減は常に有害 | **探索増加**: nearest consumer を読む 1 ステップを追加（削減なし） ✓ |
| #5 入力テンプレートの過剰規定 | **視野拡張**: 特定のラベルや値を記録させるのではなく、消費関数を読む方向へ視野を拡張 ✓ |
| #6 既存制約との差分で評価 | **既存行の精緻化**: 1 行置換。差分は「consumer on test path を読む」という方向明示のみ ✓ |
| #8 受動的記録フィールド | **能動的探索**: consumer 関数を実際に読む行動を誘発 ✓ |
| #9 メタ認知的自己チェック | **自己評価なし**: 外部的に検証可能な行動（特定関数を読む）を要求 ✓ |
| #10 必要条件ゲートの判別力 | **弁別力あり**: consumer が差分を伝播するか吸収するかは、EQUIV 偽陰性（吸収）と真 NOT_EQ（伝播）を弁別する ✓ |
| #12 アドバイザリな非対称指示 | **非対称条件なし**: verdict-specific な発火条件を持たない ✓ |
| #14 条件付き特例探索 | **主ループの改善**: 差分発見時に常時適用される中心ループの一部 ✓ |
| #16 ネガティブプロンプトの過剰適応 | **適用なし**: 禁止文ではなく肯定的な行動指示 ✓ |

---

## 7. 変更規模の宣言

- **変更形式**: 既存行への文言精緻化（1 行 → 1 行 置換）
- **追加行数**: 0（置換のため）
- **削除行数**: 0（置換のため）
- **新セクション追加**: なし
- **新フィールド追加**: なし
- **制約（追加行数 5 行以内）**: クリア
- **変更箇所**: `### Compare checklist` の 5 番目の bullet（SKILL.md line 220）のみ

---

## 付記: 参照根拠

本提案の改善仮説は iter-41（カテゴリ B、85% 達成）の実績に基づく。iter-41 は iter-35 ベース（iter-29 + 後続変更）に対して同一行の置換を行い 17/20 を達成した。本提案は同一変更を iter-29 ベースに適用するものであり、iter-35 固有の追加変更（カテゴリ C の CONTRACT DELTA 等）がなくても、対象行が iter-29 SKILL.md に存在すること（line 220）を確認済みである。

iter-47（BL-22）との差分: iter-47 は D2(b) へのネガティブプロンプト追加で失敗。本提案は Compare checklist の探索行動指示を精緻化するものであり、禁止文は含まない。
