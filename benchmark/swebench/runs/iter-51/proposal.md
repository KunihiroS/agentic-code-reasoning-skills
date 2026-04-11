# Iteration 51 — 改善案提案

## 親イテレーションの選定理由

iter-39 (75%, 15/20) を親として選定した。理由:
- iter-39 は Compare checklist に「直接変更された関数を読んだ直後に immediate caller の use を読め」という探索行動義務を 1 行追加し、iter-38 の 75% を維持した安定点である。
- この変更は Exploration Framework Category B の探索行動義務として正当であり、失敗リストとの競合もない。
- 失敗ケース構成 (EQUIV 偽陽性 1 件、NOT_EQ 偽陰性 1 件、UNKNOWN 3 件) は、まだ対処可能な余地を持つ構成である。

---

## 選択した Exploration Framework カテゴリ

**Category F: 原論文の未活用アイデアを導入する**

理由:
- iter-39 は Category B（情報取得方法の改善：immediate caller trace 追加）を用いた。
- Category D（メタ認知）は BL-9 で失敗済み。Category A（推論順序）は BL-12/BL-14 で失敗済み。Category C（比較枠組み）は BL-8/BL-10 で失敗済み。Category E（表現改善）は多数のイテレーションで副次的に試みられた。
- Category F は、原論文 §4.3 Error Analysis の「不完全な推論チェーン (Incomplete reasoning chains)」知見を SKILL.md に完全に反映させる余地がまだある。現在の Guardrail 5 はこの知見を片方向（caller が差分を吸収するか確認）にのみ実装しており、もう一方向（チェーンがテスト観測点に到達しているか確認）は未実装である。

---

## 改善仮説

**Guardrail 5 が「不完全な推論チェーン」を一方向でしか阻止していないため、反対方向の誤判定が継続している。Guardrail 5 を双方向化することで、両タイプの誤判定を同時に改善できる。**

具体的には:
- 現在の Guardrail 5 は「downstream code が差分を既に処理しているかを確認せよ」という一方向のチェック（caller が吸収→ EQUIV が正しいが NOT_EQ と誤判定 = EQUIV 偽陰性の防止）のみ実装している。
- 原論文 §4.3 の "incomplete reasoning chains" はもう一方向（チェーンが変更関数の境界で止まり、テスト観測点に達していない→ NOT_EQ が正しいが EQUIV と誤判定 = NOT_EQ 偽陰性の防止）も同等に重要とする。
- この両方向を 1 文で明示することで、エージェントは「チェーンが有効な長さを持っているか」を双方向に確認するようになり、13821 型（EQUIV→NOT_EQ）・11433 型（NOT_EQ→EQUIV）の誤判定両方を改善できる。

---

## SKILL.md への具体的変更内容

**変更箇所**: `## Guardrails` → `### From the paper's error analysis` 内の Guardrail 5（SKILL.md line 417）

**変更種別**: 既存行の文言精緻化（追加行数 0）

### 変更前

```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

### 変更後

```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify both that callers do not already normalize or absorb the identified difference before the test observes it, and that the chain connects the change to a test-observable outcome — not just to the changed function's boundary. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

### 変更内容の詳細

| 旧表現 | 新表現 | 意図 |
|--------|--------|------|
| `downstream code does not already handle the edge case or condition you identified` | `callers do not already normalize or absorb the identified difference before the test observes it` | 方向を "downstream（曖昧）" から "callers（呼び出し元 = テスト方向）" へ明確化。"handle the edge case" を "normalize or absorb the difference" へ語彙を具体化 |
| （存在しない） | `and that the chain connects the change to a test-observable outcome — not just to the changed function's boundary` | 反対方向のチェックを追加。チェーンが変更関数の境界で止まっていないか（テスト観測点まで繋がっているか）を確認する義務を明示 |

**追加行数: 0（既存行の文言精緻化のみ）**

---

## EQUIV と NOT_EQ の正答率への予測影響

### EQUIV 正答率（現在 8/10）→ 維持または改善見込み

- `callers do not already normalize or absorb` という具体的な語彙が「変更関数の return value を caller がどう使うか」を自然に確認させる。iter-39 の checklist 追加と相乗的に働き、13821 型（caller が差分を吸収するにもかかわらず NOT_EQ と誤判定）の防止に寄与。
- 15382（EQUIV→UNKNOWN）: 変更が test-observable outcome に到達しないことを早期に確認できれば、EQUIV 結論に至る思考をショートカットできる可能性がある。

### NOT_EQ 正答率（現在 7/10）→ 改善見込み

- `chain connects the change to a test-observable outcome` という新規チェックが、「変更コードの差分を発見したが、それがテスト assertion に伝播するかを確認せずに EQUIV と結論する」11433 型の誤判定を防止する。
- このチェックは探索量を増やすのではなく、既存の推論チェーンの「長さの十分性」を確認させるものであるため、BL-25（全 Claim に assertion までの完全 cite 義務）とは異なり、ターン消費の大幅な増加を招かない。
- 14787・12663（NOT_EQ→UNKNOWN）: 主要な探索義務が変わらないため、これらへの直接的な改善効果は限定的。ただし悪化リスクも低い。

### UNKNOWN 率への影響

- 本変更は Guardrails（原則）の精緻化であり、Certificate テンプレートへの新規フィールド追加ではない。エージェントへの義務として「何を確認すべきか」を明確にするが、「何を記録すべきか」は増やさない。
- したがって BL-8（受動的記録フィールド追加）・BL-10（通過コストのある条件分岐ゲート）・BL-25（完全 cite 義務）とは機能的に異なり、ターン枯渇リスクを増大させない。

---

## failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|---------------|
| BL-2 | NOT_EQ の証拠閾値・厳格化 | **非該当**: 本提案は証拠の閾値を変更しない。推論チェーンの方向性を確認させるだけ |
| BL-6 | Guardrail 4 の対称化（両方向への trace 義務追加） | **異なる**: BL-6 は "trace 義務" の対称化で立証責任を引き上げた。本提案は "チェーンの完全性確認" の観点追加であり、立証責任（証拠の閾値）は変更しない |
| BL-9 | メタ認知的自己チェック追加 | **非該当**: Guardrail は推論原則であり、TRACED/INFERRED のような自己評価フィールドではない |
| BL-14 | チェックリストへの逆方向推論追加 | **類似点あり・非該当**: BL-14 は「DIFFERENT と主張する場合にのみ」逆方向推論を要求した非対称的指示（共通原則 #12）。本提案は両方向への確認を対称的に求める（EQUIV/NOT_EQ 両方のチェーンに適用） |
| BL-23 | nearest consumer 伝播/吸収確認の義務化 | **異なる**: BL-23 は Certificate テンプレートの Claim 内に中間ノード分析を埋め込んだ。本提案は Guardrail（原則）への精緻化であり、テンプレートフィールドの追加ではない |
| BL-25 | `because` 節への assertion/exception までの完全 trace 義務 | **異なる**: BL-25 は Claim ごとに file:line citation を義務付けた。本提案は「チェーンが test-observable outcome に連結していること」の確認であり、per-Claim の完全 cite 要求ではない |

### 共通原則照合

| 原則 | 内容 | 照合結果 |
|------|------|---------|
| #1 判定の非対称操作 | 一方向有利な変更は失敗 | **適合**: (a) EQUIV 誤判定防止 + (b) NOT_EQ 誤判定防止 の対称構造 |
| #2 出力側の制約は無効 | 「こう答えろ」は効果なし | **適合**: 出力への制約ではなく、推論チェーンの品質確認 |
| #3 探索量の削減は有害 | 探索を減らす変更は悪化 | **適合**: 探索量を変更しない |
| #5 テンプレートの過剰規定 | 規定が視野を狭める | **適合**: Guardrail 精緻化であり、テンプレートフィールドの追加ではない |
| #6 対称化は差分で評価 | 既存制約との差分が一方向なら非対称 | **適合**: 差分 = (b) のチェーン完全性確認追加。これは NOT_EQ 偽陰性防止方向（EQUIV を出しにくくする）であり、既存の (a) は EQUIV 偽陰性防止方向（NOT_EQ を出しにくくする）。差分は既存制約を counterbalance する方向 |
| #12 アドバイザリでも非対称指示は失敗 | チェックリストでも立証責任非対称化は失敗 | **適合**: 本提案は EQUIV/NOT_EQ どちらの結論に対しても同じ2チェックを適用。非対称な立証責任変化なし |
| #15 固定長追跡ルールは無効 | 1 hop 等の固定追跡 | **適合**: hop 数を指定しない。「テスト観測点へ連結しているか」の確認であり、ステップ数ではなく到達性の意味論的確認 |
| #19 完全立証義務は探索枯渇を招く | per-Claim の完全 cite 義務は UNKNOWN を増やす | **適合**: Guardrail の確認義務は Claim ごとの citation 要求ではない |

---

## 変更規模の宣言

- **追加行数: 0**（既存 Guardrail 5 行の文言精緻化のみ）
- **削除行数: 0**
- **変更対象: SKILL.md の Guardrails セクション、行 417 の 1 文を精緻化**
- hard limit（追加5行以内）に対して余裕のある変更規模
