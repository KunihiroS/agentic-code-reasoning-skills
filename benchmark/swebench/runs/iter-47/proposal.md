# Iteration 47 — 改善案提案

## 親イテレーション選定理由

親イテレーション: **iter-21（スコア 85%、17/20）**

iter-21 は過去全イテレーション中で 85% を達成した複数の到達点（iter-21, 31, 35, 41）の一つだが、直近の iter-46（65%）と比較して最高スコアを持つ復元点として選定された。iter-21 の変更内容は Guardrail #10（"Commit to a conclusion. Do not answer UNKNOWN."）の追加のみであり、差分が明確で副作用が限定的。また benchmark-progression.md において、iter-21 以降の多数のイテレーションが 85% の壁を超えられていないことから、iter-21 の構造的課題（3件の失敗）に正面から向き合う必要がある。

---

## 失敗ケース分析（iter-21: 3件）

| Instance | GT | Predicted | パターン |
|---|---|---|---|
| django__django-15368 | EQUIVALENT | NOT_EQUIVALENT | パスツーパステスト削除 → NOT_EQ 誤判定 |
| django__django-15382 | EQUIVALENT | UNKNOWN | 複雑な例外制御フロートレースで収束不能 |
| django__django-14787 | NOT_EQUIVALENT | EQUIVALENT | 実差異の見落とし |

benchmark-progression.md の Persistent Failure Analysis によると、15368 の根本原因は **「Patch B がパスツーパステストを削除した事実を "test deleted = different outcome" と解釈して NOT_EQ に誤判定する」** ことであり、"SKILL fix attempted: none yet (D2 clarification is generalized, not benchmark-specific)" と明記されている。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する**
- サブ方針: 「曖昧な指示をより具体的な言い回しに変える」

### 選択理由

- iter-21 は **カテゴリ D**（メタ認知・ガードレール追加：Guardrail #10）を使用した。本提案はカテゴリ E を選択する（iter-21 では未使用）。
- 15368 の失敗原因は D2(b) の既存条件「relevant only if the changed code lies in their call path」が実際に **検証（tracing）されずに適用されている** ことにある。D2(b) は条件を明示しているが、その条件を「確認する方法」を指定していないため、モデルはテストの削除という観測事実を call path の検証なしに "relevant" と判断してしまう。
- 解決策は D2(b) の既存条件をそのまま維持しつつ、検証要件（verification requirement）を 1 文追加することで条件の暗黙的適用を明示的な trace 義務に変換すること。これは **新規ステップや新規テンプレート要素の追加ではなく**、既存指示の精緻化である。

---

## 改善仮説（1つ）

**D2(b) の「changed code lies in their call path」という条件は正しいが、モデルがこれを trace 検証なしに適用するため、テスト削除のような観測事実から call path 関連性を誤って仮定してしまう。D2(b) に「trace により検証せよ。テストの近接・共有モジュール・テストレベルの変更（削除・改名）から関連性を仮定してはならない」という検証要件を追記することで、15368 パターンの誤判定を防ぎつつ、検証要件が両方向（EQUIV・NOT_EQ）に等しく作用するため NOT_EQ 正答率を損なわない。**

---

## SKILL.md の変更内容

### 変更箇所

Compare テンプレート内の `DEFINITIONS` セクション、`D2(b)` の行。

### 変更前

```
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
```

### 変更後

```
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path. Verify this by
        tracing the test's execution; do not assume relevance from file
        proximity, shared module, or test-level changes such as deletion.
```

### 変更の説明

- 既存の条件「changed code lies in their call path」はそのまま維持する
- 末尾に 2 行（"Verify this by..." から "...deletion."）を追加する
- **追加行数: 2行**（hard limit 5行以内）
- 新規ステップ・新規フィールド・新規セクションは一切追加しない

---

## EQUIV と NOT_EQ の正答率への予測影響

### EQUIV（現状 7/10 = 70%）
- **+1 件の改善を予測（15368 が正答に転じる可能性が高い）**
- D2(b) 検証要件により、削除されたパスツーパステストの関連性が call path 検証なしに「relevant」と扱われなくなる
- 15368 は "Patch B がテストを削除 → テストが実行されない → 異なる outcome" という推論連鎖が崩れ、「そのテストは changed code の call path 上にあるか？」という検証に誘導される
- 13821・15382 への直接効果は限定的（別の失敗原因のため）
- **予測: 7/10 → 8/10（+1）**

### NOT_EQ（現状 10/10 = 100%）
- **現状維持を予測**
- 検証要件は両方向に等しく適用される（"Verify this by tracing" は call path 上に **ある** ことも **ない** ことも同様に検証させる）
- 現在の 10 件の正答 NOT_EQ ケースは、call path 上にあるテストを根拠として NOT_EQ を判定しており、検証要件の追加でその根拠が弱まる理由はない
- **予測: 10/10 → 10/10（維持）**

### 総合予測

**17/20（85%）→ 18/20（90%）** を期待する。

---

## failed-approaches.md との照合

### ブラックリストとの非抵触確認

| BL項目 | 内容 | 本提案との相違 |
|---|---|---|
| BL-1 | テスト削除を ABSENT 定義として追加 | **本提案は新規定義を追加しない**。D2(b) の既存条件（call path 上にある場合のみ relevant）をそのまま維持し、その検証方法を明示するのみ。BL-1 は削除テストを定義上 ABSENT とする（条件を変更）；本提案は条件変更なし（検証要件の明示化のみ） |
| BL-2 | NOT_EQ 判定の証拠閾値・厳格化 | **本提案は NOT_EQ 側の立証責任を引き上げない**。COUNTEREXAMPLE セクションには一切触れない。D2(b) の検証要件は「relevant test の識別プロセスの改善」であり、判定閾値の変更ではない |
| BL-18 | 削除・スキップされたテストへの条件付き repo search 義務 | **本提案は条件付き追加ステップを設けない**。BL-18 は削除テスト発見時に新たな search ステップを追加するもの；本提案は D2(b) の通常の relevance 確認を trace 義務として明示するのみ |
| BL-6 | Guardrail 4 の「対称化」 | **本提案は既存制約の対称化ではない**。D2(b) は既に両方向に中立な条件（call path 検証）を持っており、その検証方法を追記するだけ |

### 共通原則との照合

| 原則 | 評価 |
|---|---|
| 1. 判定の非対称操作は失敗する | ✅ 検証要件は両方向に等しく作用（EQUIV・NOT_EQ どちらにも偏らない） |
| 2. 出力側の制約は効果がない | ✅ 入力側の改善（relevance 確認プロセス）であり、出力への制約ではない |
| 3. 探索量の削減は有害 | ✅ 検証要件は探索を増やす（"Verify by tracing"）。削減なし |
| 4. 同じ方向の変更は同じ結果 | ✅ BL-1 は条件変更；本提案は検証方法の明示化。方向が異なる |
| 5. 入力テンプレートの過剰規定は探索視野を狭める | ✅ D2(b) の既存条件を変えず、検証方法を追記するのみ。過剰規定ではない |
| 8. 受動的記録フィールドの追加は能動的検証を誘発しない | ✅ 本提案は「記録フィールドの追加」ではなく「trace 検証の明示的要求」 |
| 9. メタ認知的自己チェックは機能しない | ✅ 自己チェック（"did I do X?"）ではなく、具体的なアクション（"trace the test's execution"）を要求 |

---

## 変更規模の宣言

- **追加行数: 2行**（hard limit 5行以内）
- 削除行数: 0行
- 変更箇所: Compare テンプレート内の `D2(b)` のみ（1箇所）
- 新規ステップ・新規フィールド・新規セクション・新規テンプレート要素の追加: **なし**
- 変更規模カテゴリ: **最小（Minimal）**
