# Iteration 30 — 改善提案（改訂版）

## 選択した Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマット改善（冗長削減・焦点の明確化）**

- 具体的サブアプローチ: 「compare テンプレートの `Comparison:` 行の比較基準点を対称的に明確化する」
- 選択理由:
  - 前回提案（カテゴリ F: Guardrail 5 への compare 向け追記）は「差異発見後の追加確認」として実効差分が NOT_EQ 方向に偏り、BL-6/BL-14 型の再発リスクが高いと判断された（監査役フィードバック参照）。
  - 今回はカテゴリ E の「追加制約」ではなく「焦点の明確化」方向を採用する。compare テンプレートの `Comparison:` 行直前に、**SAME / DIFFERENT どちらの結論にも等しく適用される基準点の明示**を 1 行追加する。新たな証明義務や条件分岐を導入せず、比較の対象を「テストが実際に観測できる最初のポイント」に両方向対称に向ける。
  - カテゴリ A〜D、F はいずれも複数回試行済みで失敗しており、カテゴリ E の「冗長削減・焦点明確化」方向は未試行に近い。過去の E 系試行はすべて BL-5/11/13 等の「追加制約」方向であり、**削減・焦点化方向は新規**である。

---

## 改善仮説

**仮説**: EQUIV 偽陽性（15368, 13821, 15382）の失敗パターンを引き起こす根本は、compare モードの `Comparison:` 判定が **コード内部の差異（関数レベルの semantic difference）** に基づいて行われることにある。テストが実際に観測できる最初のポイント（returned value / raised exception / mutated state / assertion input）まで差異が伝播するかどうかを問わず、コード差分を見た時点で DIFFERENT と結論するショートカットが発生している。

現在の compare テンプレートでは、`Claim C[N].1/2` でコードトレースを経由した後に `Comparison: SAME / DIFFERENT outcome` を記入させるが、「outcome の基準点は何か」が明示されていない。このため AI はコードレベルの差分をそのまま outcome の差分として扱いやすい。

`Comparison:` 行の直前に **1 行の基準点明示**を加えることで：
- 「比較するのは、テストが最初に観測できるポイントでの結果」という焦点を SAME / DIFFERENT 両方向に対称的に設定できる
- 新たな証明義務（追加フィールド、ゲート、逆方向推論）を課さず、既存の推論構造を変えない
- 発火条件が「差異発見時」ではなく「Comparison を記入する全局面」になるため、非対称な制約にならない

---

## SKILL.md のどこをどう変えるか

**対象箇所**: `## Compare` → `### Certificate template` → `ANALYSIS OF TEST BEHAVIOR` 内、2 か所の `Comparison: SAME / DIFFERENT outcome` 行の直前

### 変更 1（fail-to-pass tests ブロック）

**現在の記述**:
```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

**変更後の記述**:
```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  (Base this on the first observation point the test can detect — returned value,
   raised exception, mutated state, or assertion input — not merely on internal
   code differences.)
  Comparison: SAME / DIFFERENT outcome
```

### 変更 2（pass-to-pass tests ブロック）

**現在の記述**:
```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  Comparison: SAME / DIFFERENT outcome
```

**変更後の記述**:
```
For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  (Base this on the first observation point the test can detect — returned value,
   raised exception, mutated state, or assertion input — not merely on internal
   code differences.)
  Comparison: SAME / DIFFERENT outcome
```

**追加行数**: 各ブロックに 3 行（括弧付きコメント）、合計 6 行追加。削除なし。変更規模: 実質 6 行追加のみ。

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV 正答率（現在 7/10 = 70%）
- **影響**: 改善見込み
- **根拠**: 15368, 13821, 15382 の失敗原因は、コードレベルの semantic difference を見た時点で `Comparison: DIFFERENT` に飛ぶパターン。`Comparison:` 直前に「テストが実際に観測できるポイントで判断せよ」という基準点を置くことで、AI は Claim C[N].1/2 のトレース結果（PASS/FAIL）に立ち戻って判定するようになる。これは新規の検証義務ではなく、既に書かれた Claim の正しい読み方を示す焦点明確化であり、探索量を増やさない。
- **予測**: 1-2 ケース改善 → 8-9/10（80-90%）

### NOT_EQ 正答率（現在 8/10 = 80%）
- **影響**: 中立
- **根拠**: 追加文は SAME・DIFFERENT どちらを書く局面でも等しく適用される（発火条件は「差異発見時」ではなく「Comparison 記入時」）。真の NOT_EQ ケースでは Claim C[N].1/2 が既に FAIL/PASS の divergence を示しており、基準点明示はその判断を変えない。BL-14 の「DIFFERENT 主張時のみ backward verify を要求する」構造とは根本的に異なる。12663 型（ターン上限 UNKNOWN）への直接効果は薄いが、悪化もしない。
- **予測**: 変化なし（8/10）

### 総合予測
- 現在 15/20（75%）→ 16-17/20（80-85%）

---

## failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|----------------|
| BL-1 | ABSENT 定義追加（テスト除外） | 無関係 |
| BL-2 | NOT_EQ 証拠閾値の厳格化 | **異なる**: COUNTEREXAMPLE ブロックを変更しない。「NOT_EQ と主張する場合のみ追加検証」という非対称構造を一切持たない |
| BL-3 | UNKNOWN 禁止 | 無関係 |
| BL-4 | 早期打ち切りゲート | 無関係（探索量を変えない） |
| BL-5 | P3/P4 アサーション形式強制 | 無関係（PREMISES を変更しない） |
| BL-6 | Guardrail の「対称化」（差異発見後の追加確認） | **異なる**: BL-6 の実効差分は「差異があると結論する前にも trace せよ」という NOT_EQ 側への追加検証義務だった。本提案の発火条件は「差異発見時」ではなく「Comparison を記入する全局面」であり、SAME を書くときも DIFFERENT を書くときも等しく適用される。既存制約との差分が両方向均等 |
| BL-7 | 変更性質の中間ラベル生成 | 無関係（ラベル生成を要求しない） |
| BL-8 | テーブル列追加（受動的記録） | 無関係（新フィールドを追加しない） |
| BL-9 | メタ認知的自己チェック行 | 無関係（自己評価チェックを追加しない） |
| BL-10 | 到達性ゲート（YES/NO 条件分岐） | 無関係（条件分岐を導入しない） |
| BL-11 | `outcome mechanism` 注釈（ANALYSIS に視野拡張 1 文追加） | **要注意・異なる**: BL-11 は ANALYSIS 冒頭に「mechanism を列挙せよ」という追加観点を挿入し、新たなアンカーとなった。本提案は新たな観点の列挙ではなく、「既に Claim で書かれた PASS/FAIL に基づいて判定せよ」という焦点の絞り込みであり、追加の記述義務を生まない |
| BL-12 | テストソース先読み順序固定 | 無関係（探索順序を変更しない） |
| BL-13 | Key value データフロー欄追加 | 無関係（新フィールドを追加しない） |
| BL-14 | DIFFERENT 主張時の backward verify 要求 | **異なる**: BL-14 は「DIFFERENT と主張する場合のみ」逆方向検証を要求した。本提案は結論方向に依存せず `Comparison:` 記入のたびに適用され、非対称な適用条件を持たない |
| BL-15 | COUNTEREXAMPLE の `By P[N]` 削除（出力側 wording 修正） | **異なる**: BL-15 は探索行動を変えない出力側の整形変更だった。本提案は推論の判定基準点をテンプレート内で明示することで、Claim から Comparison への推論ステップの焦点を変える |

### 共通原則との照合

| 原則 | 内容 | 判定 |
|------|------|------|
| #1 判定の非対称操作 | 一方に有利な変更は失敗 | **PASS**: `Comparison:` 行は SAME / DIFFERENT 両方向で等しく適用される。「差異発見時」という非対称な発火条件を持たない |
| #2 出力側制約は効果なし | 「こう答えろ」系の制約 | **PASS**: 出力値の制約ではなく、判定基準点の明示。`Comparison:` に入れる値を制約するのではなく、何に基づいて判定するかを明確化する |
| #3 探索量の削減は有害 | 探索を減らす変更は悪化 | **PASS**: 追加の探索ステップを要求しない（既に Claim C[N].1/2 でトレース済みの情報に基づいて判定するよう焦点を当てるだけ） |
| #4 同じ方向の変更 | 表現違いでも同じ効果 | **PASS**: 過去の Guardrail 追記・逆方向推論・downstream 確認とは方向が異なる。「何を確認するか」ではなく「何を比較基準にするか」を明示する（焦点の移動、追加義務の不在） |
| #5 テンプレート過剰規定 | 記録対象の限定 | **PASS**: 追記は括弧付きコメントで新規フィールドを作らない。記録すべき対象を新たに追加するのではなく、既存 Claim の読み方を示す |
| #6 対称化の実効差分 | 既存制約との差分を見よ | **PASS**: 変更前との差分は「`Comparison:` 記入時の基準点明示」のみ。この差分は SAME 判定時も DIFFERENT 判定時も等しく働く。既存制約（Guardrail 5 等）との重複なし |
| #7 中間ラベルのアンカリング | 分類ラベルが後続推論を固定 | **PASS**: 「returned value / exception / mutated state / assertion input」は比較基準点の列挙であって中間ラベル（変更の性質分類）ではない。後続の FORMAL CONCLUSION への分類バイアスを生まない |
| #8 受動的記録 ≠ 能動的検証 | 記録フィールドは検証を誘発しない | **PASS**: 新規フィールドを追加しない。既に存在する Claim C[N].1/2 の PASS/FAIL を正しく参照するよう焦点を当てる |
| #9 メタ認知自己チェックの限界 | 自己評価精度の限界 | **PASS**: AI 自身の行動を自己評価させない |
| #10 必要条件ゲートの弁別力 | ゲート条件が失敗モードと直交すれば無効 | **PASS**: ゲートではない。YES/NO 分岐もない |
| #11 探索順序固定の偏り | 片側起点強制はアンカリングを生む | **PASS**: 探索順序を変更しない |
| #12 アドバイザリな非対称指示 | チェックリスト形式でも立証責任を上げる | **PASS**: SAME / DIFFERENT いずれの結論を出す局面でも等しく適用されるため、「DIFFERENT を主張する場合のみ追加立証」という構造がない |

---

## 変更規模

- 変更箇所: compare テンプレート内 `ANALYSIS OF TEST BEHAVIOR` の 2 か所（fail-to-pass / pass-to-pass 各ブロック）
- 追加行: 各 3 行 × 2 箇所 = 合計 6 行（括弧付きコメント）
- 削除行: 0 行
- **合計差分: 10 行以内に収まる**
