# Iteration 36 — 改善案（差し戻し後再提案）

## 前回提案の却下理由と方針転換

前回提案（D2 の (b) 項に「削除・スキップされたテストは元から D2 relevant でない限り counterexample にならない」という carve-out を追記）は、以下の理由で却下された：

- 実効差分が「削除・スキップテストを比較対象から定義上除外する」規則の追加であり、**BL-1 の Fail Core（比較対象から特定テストを除外するルール追加）と実質同型**
- 実効差分は EQUIV 側に有利・NOT_EQ 側に不利の一方向であり、共通原則 #1（判定の非対称操作）・#6（対称化の実効差分）に抵触
- 論文・RTS 研究が支持するのは「affected tests を精度よく見つけること」であって、removed/skipped test を定義で除外する carve-out ではない

監査役の推薦に従い、**カテゴリ B（情報の取得方法を改善する）** として、「削除・スキップされたテストを counterexample として採用する前に、そのテストが patch 前に変更コードを実際に exercise していたかをリポジトリ検索で確認する」探索行動を追加する。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ B — 情報の取得方法を改善する**

> 「何を探すかではなく、どう探すか・何を確認してから判断するかを改善する」

### 選択理由

現行の失敗モード（15368）の本質は、エージェントが「patch がテストを削除した」という事実を観察した後、そのテストが変更コードを exercise していたかを**確認せずに** COUNTEREXAMPLE として採用することにある。

これは「定義が曖昧だから」ではなく「**証拠採用前の情報取得が不足している**」という問題である。D2 の定義を変えるのではなく、Compare checklist に「test 削除・スキップを見つけたら、その test が patch 前に変更コードのコールパス上にあったかをリポジトリ検索で確認する」という探索行動義務を追加することで、**根拠のある証拠採用プロセスの質を向上させる**。

### 過去の Category B 試行との差分確認

| 過去の試行 | 機構 | 今回との違い |
|---|---|---|
| BL-8 (iter-7) | Step 4 テーブルに `Relevant to` 列を追加（受動的記録フィールド） | 今回はフィールド追加ではなく、**特定状況（test 削除検出時）に能動的リポジトリ検索を行う行動義務** |
| BL-10 (iter-7) | `Reachability` ゲート（変更コードへの到達確認） | BL-10 は「到達するか」の YES/NO ゲートで、relevant test に対してほぼ常に YES になり弁別力がなかった。今回は「**patch 前に**コールパス上にあったか」を**削除・スキップが発生した場合のみ**確認する。条件付きで、かつ historical exercise の確認（具体的な grep/search 行動）を要求する点が異なる |

---

## 現状の失敗パターン分析

**現スコア: 85%（17/20）**

| ケース | 正解 | 予測 | 失敗原因 |
|--------|------|------|----------|
| 15368 | EQUIVALENT | NOT_EQUIVALENT | Patch B がテストファイルから ~14 件のテストを削除。エージェントはその削除を「テストが実行されなくなる = NOT_EQ の反例」として採用したが、それらのテストが変更コードのコールパス上にあったかを確認しなかった |
| 13821 | EQUIVALENT | NOT_EQUIVALENT | 「SQLite 3.9.0–3.25.x という仮想環境」でのみ異なる挙動を COUNTEREXAMPLE とした。実際の CI は SQLite >= 3.26.0 であり、D2 に listing されていない環境仮定を証拠として採用した |
| 11433 | NOT_EQUIVALENT | UNKNOWN | 31 ターン消費後に収束失敗。本提案の主対象外 |

### 根本問題：test 削除・スキップ検出時に確認行動がない

15368 の失敗の本体は「コールパスを確認せずに test 削除を反例採用する」という**証拠採用前の情報収集不足**である。エージェントは以下の短絡を取った：

1. Patch B が tests.py から多数のテストを削除していることを観察
2. 削除されたテストが「実行されなくなる」= 動作差分 → COUNTEREXAMPLE と即断
3. それらのテストが変更されたコード（`BaseDatabaseSchemaEditor`）を exercise していたかを検索・確認しなかった

**必要な行動**: test 削除・スキップを発見したら、リポジトリ内でそのテストが変更されたシンボルを実際に呼び出していたかを検索し、確認できなければ counterexample として使わず P[N] の制約として記録する。

---

## 改善仮説（1つ）

> **Compare checklist に「test 削除・スキップを見つけたら、そのテストが patch 前に変更コードのコールパス上にあったかをリポジトリ検索で確認する義務」を1項目追加することで、根拠のない test 削除反例の採用を防ぎ、EQUIV 偽陰性を削減できる。**

これは D2 の定義を変えず、**証拠採用前の情報取得改善**（カテゴリ B）として実現する：
- 確認できた場合: 依然として有効な counterexample として使える（NOT_EQ 側への影響を最小化）
- 確認できない場合: P[N] の scope constraint として記録し、counterexample には使わない

---

## SKILL.md の変更内容

**変更箇所**: Compare checklist に1項目を追加する。

### 変更前

```
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

### 変更後

```
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- If either patch removes or skips a test, search the repository to confirm that test called the changed code path before treating it as a counterexample; if unconfirmed, record it as a scope constraint in P[N] instead
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

**変更規模**: 1行追加（checklist 末尾から2番目に挿入）

---

## EQUIV と NOT_EQ の両方の正答率への予測影響

| カテゴリ | 現状 | 予測 | 理由 |
|--------|------|------|------|
| EQUIV (10件中 8件正答, 80%) | 80% | 85–90% | 15368 パターン（test 削除を根拠確認なしに反例採用）の誤判定を防げる可能性が高い。エージェントが削除テストの call path を確認 → 変更コードを呼び出していないことを発見 → P[N] 制約化 → EQUIV 判定 |
| NOT_EQ (10件中 10件正答, 100%) | 100% | 95–100% | 真の NOT_EQ ケースでは test 削除が反例になるとしても、それは変更コードを exercise しているテストの削除であり、リポジトリ検索で確認できる。確認できれば依然として有効な counterexample として使える。軽微な探索オーバーヘッドのリスクあり |
| 全体 | 85% | 88–90% | |

---

## failed-approaches.md ブラックリストおよび共通原則との照合

| 確認項目 | 判定 | 根拠 |
|--------|------|------|
| BL-1（ABSENT 定義追加） | ✅ 非該当 | D2 の定義を変えない。比較対象からテストを除外する規則を追加しない |
| BL-2（NOT_EQ 証拠閾値引き上げ） | ✅ 非該当 | 全般的な NOT_EQ 立証責任の引き上げではない。「test 削除・スキップが発生した場合のみ」確認行動を要求する条件付きの探索義務 |
| BL-6（「対称化」は差分が非対称） | ✅ 非該当 | 変更は checklist への1行追加のみ。既存の EQUIV 側ガード（checklist item 5）を変更しない |
| BL-7（分析前の中間ラベル生成） | ✅ 非該当 | 中間ラベルを生成させない。「repo search で確認する」という具体的な探索行動を要求 |
| BL-8（受動的記録フィールド追加） | ✅ 非該当 | フィールドを追加しない。能動的なリポジトリ検索を義務付ける行動指示 |
| BL-10（Reachability ゲート） | ✅ 非該当 | BL-10 は全 relevant test に適用される常時ゲートで弁別力がなかった。今回は「test 削除・スキップを検出した場合のみ」適用される条件付き検索義務であり、かつ「patch 前の historical exercise」を確認する点が異なる |
| 共通原則 #1（判定の非対称操作） | ✅ 非該当 | 確認できれば counterexample として使える（NOT_EQ 保護）、確認できなければ P[N] に記録（誤採用防止）。両方向に対称的に作用する |
| 共通原則 #3（探索量削減は有害） | ✅ 非該当 | 探索を増やす変更（追加的なリポジトリ検索を要求） |
| 共通原則 #4（同方向の変換は同結果） | ✅ 非該当 | BL-1 系（除外規則追加）ではなく、BL-1 の根本問題（証拠確認不足）に対する情報取得改善 |
| 共通原則 #8（受動的記録は検証を誘発しない） | ✅ 非該当 | 記録フィールドを追加するのではなく、「リポジトリ検索で確認する」という能動的検証行動を直接要求 |
| 共通原則 #10（必要条件ゲートは弁別力を持たない） | △ 要確認 | BL-10 と近い懸念があるが、今回の条件「削除・スキップが発生したとき」は弁別力がある（削除されていなければ発動しない）。かつ確認行動自体が新たな証拠（call path の有無）を生成する |

---

## 変更規模

- **追加行数**: 1行（Compare checklist への1項目追加）
- **削除行数**: 0行
- **影響範囲**: Compare checklist のみ
- **研究コア構造**: 維持（番号付き前提・仮説駆動探索・手続き間トレース・必須反証は変更なし）
