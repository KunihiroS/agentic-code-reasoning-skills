# iter-54 改善提案

## 親イテレーション iter-39 の選定理由

iter-39 (スコア 75%) は直近の有効なベースラインとして選定した。iter-41 (85%) は
iter-39 より上位だが、iter-39 のブランチから出発することが指示されているため iter-39 を親とする。
iter-39 では5件の失敗（13821, 15382, 14787, 11433, 12663）があり、特に EQUIV 誤判定
（13821: EQUIV → NOT_EQ）と UNKNOWN（15382, 14787, 12663: 31 turns 到達）が顕著だった。

## 選択した Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する** — 「曖昧な指示をより具体的な言い回しに変える」

iter-39 はカテゴリ A/B（Compare checklist への探索行動義務追加）を用いた。
カテゴリ E は今回の親イテレーションでは未使用であり、既存の Guardrail 5 の用語の曖昧さを
解消することで認知的理解を改善できると判断した。

新規ステップ・フィールド・テンプレート要素の追加は一切行わない。

## 改善仮説

**仮説**: Guardrail 5 の「downstream code」という用語が曖昧であるため、
エージェントが「downstream = callee（呼び出し先）」と誤解し、
「変更関数 → 呼び出し先」方向のみを検証して「変更関数 → 呼び出し元 caller → テスト assertion」
方向の確認を省略している可能性がある。
`compare` モードでは「downstream」を「テスト call path 上の callers（変更関数の出力を受け取る側）」
として明示することで、Guardrail 5 が意図した「不完全な推論チェーンを信用するな」という原則が
compare モードで正しく機能するようになる。

これにより、変更関数でコード差分を発見した後に caller が差分を吸収・正規化するかを
確認するという動作が、既存の checklist 項目（iter-39 追加済み）と Guardrail の両面から
強化される。

## SKILL.md のどこをどう変えるか

### 対象

Guardrails セクションの Guardrail 5（既存行への文言追加）

### 変更内容

**変更前:**
```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

**変更後:**
```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified — in `compare` mode, callers on the test call path are downstream, not just callees. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
```

追加内容: `— in \`compare\` mode, callers on the test call path are downstream, not just callees.`（既存行の文中への挿入）

## EQUIV と NOT_EQ 両方の正答率への影響予測

### EQUIV 正答率（iter-39 で 7/10）→ 8/10 改善見込み

- **13821（EQUIV → NOT_EQ）**: エージェントが変更関数でコード差分を発見した際、
  Guardrail 5 の「downstream code には callers も含まれる」という明示的な指示により、
  caller が差分を吸収しているかを確認する動機が強化される。EQUIVALENT への正答改善が期待できる。
- **15382（EQUIV → UNKNOWN）**: 31 turns で結論未達。本変更の直接的な作用は限定的。

### NOT_EQ 正答率（iter-39 で 8/10）→ 8/10 維持見込み

- 真の NOT_EQ では caller が差分を伝播させるため、caller を確認しても NOT_EQ の根拠が
  強化されるだけで判定は変わらない。立証責任の非対称化は発生しない。
- UNKNOWN 案件（14787, 12663）への影響は indirect であり、本変更だけで回復するとは
  断言できないが、悪化させる要因も見当たらない。

## failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|--------------|
| BL-2 | NOT_EQ の証拠閾値・厳格化 | ✅ 非該当：判定閾値を操作しない。Guardrail の用語を明確化するのみ |
| BL-6 | Guardrail 4 の対称化 | ✅ 非該当：Guardrail 4 ではなく Guardrail 5 を修正。対称化ではなく用語定義の明確化 |
| BL-9 | メタ認知的自己チェック追加 | ✅ 非該当：自己評価フィールドを追加しない |
| BL-14 | 逆方向推論義務（Backward Trace）| ✅ 非該当：逆方向推論を要求しない |
| BL-21 | 1-hop downstream 固定ルール | ✅ 非該当：固定 hop 数を指定しない。方向性（callers が downstream）の定義のみ |
| BL-23 | nearest consumer 伝播/吸収の義務化 | 近接だが非該当：BL-23 は Checklist に新規 ACTION を追加した。本提案は Guardrail の用語定義を既存行内で精緻化するのみ。新規 checklist item・記録フィールド・アクション義務は追加しない |
| BL-26 | Guardrail 5 への双方向完全義務追加 | 近接だが非該当：BL-26 は「callers が吸収しないこと」と「テスト観測点まで繋がること」の 2 つの verify 義務を追加した。本提案は「callers も downstream である」という用語定義の明確化に限定し、新たな verify 義務を追加しない |

### 共通原則との照合

| # | 原則 | 照合結果 |
|---|------|---------|
| #1 | 判定の非対称操作は失敗する | ✅ EQUIV/NOT_EQ 双方向に中立。用語定義の明確化は閾値移動を生じない |
| #2 | 出力側の制約は効果がない | ✅ 出力を制約しない。Guardrail の意味的精緻化 |
| #3 | 探索量の削減は有害 | ✅ 探索量を削減しない。むしろ caller 方向の探索を促進 |
| #4 | 同方向変更は同結果 | ✅ 方向性: iter-39 は Checklist 追加、本提案は Guardrail 既存行精緻化。機構が異なる |
| #5 | 入力テンプレートの過剰規定は視野を狭める | ✅ 記録フィールドや必須記述を追加しない。用語の意味を明確化するのみ |
| #6 | 対称化は既存差分で評価せよ | ✅ 既存 Guardrail 5 は「downstream を verify せよ」という義務が既にある。本提案はその用語範囲を compare モード向けに明確化するもので、新規義務を追加しない |
| #8 | 受動的記録は能動検証を誘発しない | ✅ 記録フィールドを追加しない |
| #15 | 固定長局所追跡ルールを観測境界の代わりに使うな | ✅ 固定 hop 数を指定しない |
| #19 | エンドツーエンド完全立証義務は予算枯渇を招く | ✅ 完全立証を義務付けない。「callers も downstream」という方向定義のみ |

## 変更規模の宣言

- **追加行数**: 0 行（既存の 1 行への文言追加・精緻化。新規行の追加なし）
- **削除行数**: 0 行
- **変更の種類**: 既存 Guardrail 5 の文中に補足句を挿入
- **変更規模**: 極小（1 文中への句挿入）
