# Iteration 58 — 改善案提案

## 親イテレーション (iter-21) の選定理由

iter-21 はスコア 85%（17/20）を達成した現在の最良親である。  
ガードレール #10「Commit to a conclusion」を追加した回であり、前回 iter-20 の悪化（65%）から 85% へ回復させた実績がある。  
ただし、残存する 3 件の失敗（15368, 15382, 14787）はいずれも "結論の出しやすさ" ではなく **"証拠の質と連鎖の完全性"** の問題に起因しており、さらなる改善の余地がある。

## 選択した Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する**  
（「曖昧な指示をより具体的な言い回しに変える」）

### 理由

- カテゴリ A（順序変更）: BL-4, BL-12 により封鎖
- カテゴリ B（情報取得方法）: BL-5, BL-17, BL-18 により封鎖
- カテゴリ C（比較の枠組み）: BL-7, BL-23 により封鎖
- カテゴリ D（メタ認知・自己チェック）: BL-9, BL-10 により封鎖
- カテゴリ F（原論文未活用）: 論文の error analysis 6 原則は既に Guardrails §1–6 として反映済み
- **カテゴリ E** は "追加や構造変更なし・既存行の精緻化のみ" という制約と最も整合しており、かつ具体化により推論品質を向上させる可能性が残っている

カテゴリ E の試行履歴（BL 参照）は、新規フィールドや新規テンプレート要素の追加が伴う場合に失敗しているが、**既存の 1 行を意味を保ちながら言い回しを精緻化する** アプローチ（pure text refinement）はまだ試されていない。

## 改善仮説（1 つだけ）

**Guardrail 5 の「downstream code」という曖昧な表現が、エージェントに "テストの最終アサーション" まで追跡する義務を明示していないため、テストが実際に差異を観測するかどうかを確認せず NOT_EQ または EQUIV に結論付ける誤りが生じている。**

「downstream code」を **「downstream code — including the test assertions themselves」** に具体化することで、推論連鎖の終点をテストの観測点まで明示し、差異の "到達性検証" の質が向上する。

**根拠**:

1. **15368 の失敗構造（EQUIV→NOT_EQ）**: エージェントはコード上の意味的差異を見つけ NOT_EQ と結論するが、その差異がテストのアサーションまで伝播するかを確認していない。Guardrail 5 の「downstream code」にテストのアサーションが明示的に含まれていないことが、この検証を省略させる。
2. **14787 の失敗構造（NOT_EQ→EQUIV）**: エージェントは差異を見落とし EQUIV と結論するが、テストのアサーションから逆算してどの差異が観測可能かを確認していない。同じ Guardrail を逆方向から適用すれば、"テストが実際に観測できる差異があるか" の検証が強まる。
3. **BL-3 の示す限界**: 15382 の UNKNOWN は "結論の強制" では解決せず、証拠収集の質の問題である。本提案は UNKNOWN 禁止ではなく、証拠連鎖の精度を高める方向であり BL-3 とは独立。
4. **対称性**: 本変更はどちらの判定方向（EQUIV/NOT_EQ）にも均等に適用され、一方の立証責任のみを引き上げない（共通原則 #1 を回避）。

## SKILL.md の変更内容

**変更箇所**: Guardrails セクション、§5（line 416 付近）

```diff
-5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
+5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code — including the test assertions themselves — does not already neutralize the effect you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

**変更内容の説明**:

| 変更前 | 変更後 | 意図 |
|--------|--------|------|
| `downstream code` | `downstream code — including the test assertions themselves` | 推論連鎖の終点をテストのアサーションまで明示 |
| `does not already handle` | `does not already neutralize` | "処理する" より "無効化する" の方が "差異が消える" という比較タスク固有の概念に精確 |
| `the edge case or condition you identified` | `the effect you identified` | "edge case" は例外的な状況を示唆するが、一般的な動作差異にも適用すべきであり "effect" に汎化 |

追加行数: **0 行**（既存 1 行の文言精緻化のみ）

## EQUIV と NOT_EQ の正答率への影響予測

### EQUIV 正答率（現在: 8/10 = 80%）

- **改善予測**: +1 〜 +2 件
- 15368（EQUIV→NOT_EQ）: Guardrail 5 が「テストのアサーション自体が差異を観測するか確認せよ」と明示されることで、コード上の差異を発見しても NOT_EQ に飛びつく前にテストアサーションまでの追跡が促される。改善可能性: **中〜高**
- 15382（EQUIV→UNKNOWN）: 直接的な対処ではないが、証拠連鎖を "テストアサーション" まで整理することで、証拠の評価軸が明確になり UNKNOWN を減らす間接的効果を期待。改善可能性: **低〜中**

### NOT_EQ 正答率（現在: 9/10 = 90%）

- **改善予測**: ±0 件
- 14787（NOT_EQ→EQUIV）: テストのアサーションが差異を観測するかを確認するよう促されることで、見落としが減少する可能性あり。ただし改善は確実ではない。改善可能性: **低〜中**
- 現在正解の 9 件: 本変更は既存の Guardrail の言い回しを精緻化するだけであり、已に正しくトレースできているケースへの回帰リスクは極めて低い。

### 想定スコア: 85% → 88〜90%（17→18 件程度の改善を期待）

## failed-approaches.md のブラックリスト・共通原則との照合

| 確認事項 | 判定 | 根拠 |
|----------|------|------|
| BL-1（ABSENT 定義追加）| 非該当 | テスト除外ルールを追加しない |
| BL-2（NOT_EQ 証拠閾値厳格化）| 非該当 | 判定閾値を変更しない |
| BL-3（UNKNOWN 禁止）| 非該当 | 出力制約ではなく証拠連鎖の精度向上 |
| BL-4（早期打ち切り）| 非該当 | 探索を削減しない |
| BL-5〜BL-12（各種構造追加）| 非該当 | 新規フィールド・新規ステップ・テンプレート追加なし |
| BL-14（非対称アドバイザリ）| 非該当 | 変更は EQUIV・NOT_EQ 両方に対称に作用する |
| BL-21（fixed-hop rule）| 非該当 | hop 数を指定していない。終点の意味論的明示のみ |
| BL-22（ネガティブ禁止）| 非該当 | 「〜するな」という形式ではない |
| BL-25, BL-26（全 claim の E2E 義務化）| 非該当 | 全 claim に適用するのではなく Guardrail の説明文を精緻化するのみ |
| BL-29（証拠言い換えで立証責任引き上げ）| 要注意・問題なし | `neutralize` は `handle` より精確だが、これ自体が新たな証拠要件を追加するものではない |
| 共通原則 #1（非対称操作禁止）| 非該当 | 変更は両方向に等しく適用され、どちらの判定方向にも有利・不利を与えない |
| 共通原則 #2（出力側制約は無効）| 非該当 | 出力への制約ではなく処理側（推論プロセス）の改善 |
| 共通原則 #3（探索量削減禁止）| 非該当 | 探索量を削減しない |
| 共通原則 #8（受動記録は能動検証を誘発しない）| 非該当 | 新規記録フィールドを追加しない |
| 共通原則 #9（メタ認知チェックは無効）| 非該当 | yes/no チェックボックスではなく、既存文の言い回し精緻化 |

## 変更規模の宣言

- **追加行数**: 0 行（hard limit 5 行以内 → 余裕あり）
- **削除行数**: 0 行
- **変更行数**: 1 行（Guardrail §5 の既存行を文言精緻化）
- **影響範囲**: Guardrails セクションの §5 のみ。テンプレート・ステップ・モード分岐・チェックリスト・他セクションへの影響なし
