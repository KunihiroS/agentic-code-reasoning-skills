# Iteration 63 — 改善提案

## 親イテレーション (iter-49, フォーカス: equiv) の選定理由

iter-49 は iter-35（85%, 17/20）を親とし、Guardrail 10（BL-24）を追加した結果スコアが 75%（15/20）に低下した。
この5ケースの回帰を直接起こしたのが Guardrail 10 の追加であることは BL-24 として記録済みである。
今回は iter-49 を親として選定し、その SKILL.md（Guardrail 10 を含む状態）から改善を行う。

iter-49 の失敗ケース（5件）:
- **15382**: EQUIV → NOT_EQUIVALENT（誤）— iter-35 では正答していたが iter-49 で回帰
- **14787**: NOT_EQUIVALENT → UNKNOWN（31 ターン消費）
- **14122**: NOT_EQUIVALENT → UNKNOWN（31 ターン消費）
- **10999**: NOT_EQUIVALENT → UNKNOWN（31 ターン消費）
- **12663**: NOT_EQUIVALENT → UNKNOWN（31 ターン消費）

重要な事実: iter-35 の失敗ケース（15368, 13821, 11433）に 15382 は含まれていない（iter-35 で 15382 は正答）。つまり 15382 の誤判定は Guardrail 10 の追加によって引き起こされた回帰である。

---

## Exploration Framework カテゴリ：E

> **冗長な部分を簡潔にして認知負荷を下げる**

### 選択理由

iter-49 はカテゴリ F（論文のエラー分析セクションの知見を反映）を使用した。本提案ではカテゴリ E を選択する。

Guardrail 10 は、環境バージョン（DBバージョン、OS、インタープリタ等）に依存する挙動を証拠として使う際、テストの skip デコレータや CI 設定の `file:line` を明示的に検証することを義務付けた。この要件が以下のオーバーヘッドを生んだ:

1. **NOT_EQ ケース（14787, 14122, 10999, 12663）**: 環境依存が疑われる差異を持つケースで、モデルが skip 条件や設定ファイルを探し続けターン予算を枯渇させ UNKNOWN を引き起こした。
2. **EQUIV ケース（15382）**: 15382 は iter-35 で正答していた。Guardrail 10 が加わることで、モデルが不要な環境バージョン検証を行い、本来 EQUIVALENT と判定すべきケースで誤判定を引き起こした。

カテゴリ E の「冗長な部分を簡潔にして認知負荷を下げる」に合致する: Guardrail 10 は推論に不要な検証義務を加え、認知負荷とターン消費を増加させた。これを削除することで SKILL.md の表現が簡潔になる。

---

## 改善仮説（1つ）

**仮説**: Guardrail 10（BL-24）は iter-49 で追加され、環境バージョン仮定に対する `file:line` 検証義務を全テスト分析ループに課した。これが各テスト分析のターンコストを増大させ、4 件の NOT_EQ UNKNOWN と 1 件の EQUIV 誤判定（15382 の回帰）を引き起こした。Guardrail 10 を削除することで、iter-35 が達成した推論品質（17/20 = 85%）に加え、15382 の回帰も解消され、最大 20/20 = 100% への改善が見込まれる。

---

## SKILL.md への変更内容

### 場所

`## Guardrails` → `### From the paper's error analysis` セクション、項目 10（Guardrail 10）の全文。

### 削除対象（line 419、1行）

```
10. **Do not use unverified runtime-environment claims as evidence.** If a behavioral difference between changes is attributed to a specific database version, OS, interpreter version, or library version, that version constraint must be explicitly encoded in the test's skip decorators, setup fixtures, or CI configuration, cited at a specific file:line. A version range or environment assumption that cannot be grounded in the repository is UNVERIFIED and must not determine EQUIVALENT or NOT_EQUIVALENT conclusions.
```

### 追加なし

追加行: 0 行。削除のみ。

### 変更規模

- **追加行数**: 0 行（hard limit 5 行以内 ✓）
- **削除行数**: 1 行（制限対象外）
- **既存行の変更**: なし
- **新規セクション追加**: なし

---

## EQUIV / NOT_EQ の正答率への影響予測

### EQUIV 正答率（現在 9/10 = 90%）

- **15382（改善見込み）**: iter-35 では正答しており、Guardrail 10 が追加された iter-49 で初めて誤判定が発生。Guardrail 10 削除により iter-35 相当の推論に戻り、EQUIVALENT に正しく収束する可能性が高い。
- **その他 EQUIV 9 件（影響なし）**: iter-49 で既に正答しており、Guardrail 10 の削除は作用しない。
- **予測**: 90% → 100%（9/10 → 10/10）

### NOT_EQ 正答率（現在 60% = 6/10）

- **14787, 14122, 10999, 12663（改善見込み）**: BL-24 の記録によれば、この 4 件は Guardrail 10 追加により iter-35 の正答から UNKNOWN（31 ターン）に転落した。Guardrail 10 削除により iter-35 相当の推論に戻り、正しく NOT_EQUIVALENT に収束する可能性が高い。
- **その他 NOT_EQ 6 件（影響なし）**: iter-49 で既に正答しており、Guardrail 10 の削除は作用しない。
- **予測**: 60% → 100%（6/10 → 10/10）

### 全体予測: 75%（15/20）→ 100%（20/20）

---

## failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト非該当の確認

| BL | 本提案との関係 |
|----|--------------|
| BL-2（NOT_EQ 証拠閾値厳格化） | Guardrail 10 削除は証拠閾値を引き上げるのではなく、特定の検証義務を解除する。結果として NOT_EQ の正答率が上がることが期待される（閾値を下げる方向） |
| BL-24（Guardrail 10 追加） | 本提案は BL-24 の revert である。BL-24 自体の追加失敗がブラックリスト登録の根拠であり、その削除は合理的な回復策 |
| BL-30（制約の単純な削除） | BL-30 は「探索指針を提供していた制約を無目的に削除して探索が無秩序化した」失敗。本提案が削除するのは探索指針ではなく「特定の証拠カテゴリへの追加検証義務」であり、削除後も探索方向は SKILL.md の Compare テンプレートおよびチェックリストにより明確に導かれる。削除の目的（ターン消費削減・UNKNOWN 解消）も明確であり「無目的化」ではない |

### 共通原則との照合

| 原則 | 照合結果 |
|------|---------|
| #1 判定の非対称操作 | Guardrail 10 削除は EQUIV・NOT_EQ の両方向に同時に作用する（EQUIV 1 件と NOT_EQ 4 件を同時に回復）。非対称操作ではない |
| #2 出力側の制約 | 出力テンプレートを変更しない。証拠採用基準（入力・推論側）から過剰な検証義務を除去する |
| #3 探索量の削減 | 探索量の上限を設けるのではなく、特定の証拠への「確認義務による余分な探索」を解除する。主比較ループを圧迫していたオーバーヘッドの除去であり、探索の質・量の削減ではない |
| #18 証拠品質の厳格化によるターン枯渇 | Guardrail 10 はこの原則の典型例として BL-24 の Fail Core で言及されている。その削除は原則 #18 に完全に沿う対応 |
| #22 無目的化された削除 | 目的が明確（ターン消費削減・UNKNOWN 解消・回帰の回復）であり、削除後の探索方向は既存の Compare テンプレートが提供する。無目的ではない |

---

## 変更規模の宣言

- **追加行数**: 0 行（hard limit 5 行以内 ✓）
- **削除行数**: 1 行（制限対象外）
- **変更範囲**: `## Guardrails` セクション、項目 10 の1行削除のみ
- **新規セクション・テンプレート要素の追加**: なし
