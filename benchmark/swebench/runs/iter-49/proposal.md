# Iteration 49 — 改善提案

## 親イテレーション (iter-35) の選定理由

iter-35 は現在のベースラインスコア 85%（17/20）を達成しており、直近のイテレーション群（iter-36〜48）は全て iter-35 以下のスコアで終わっている。iter-35 を親とし、その SKILL.md から再出発することが最も堅実な出発点であるため選定した。

iter-35 の失敗ケース（3件）:
- **15368**: EQUIV → NOT_EQUIVALENT（誤）— Patch B がテストを削除。削除されたテストをそのまま counterexample に採用した
- **13821**: EQUIV → NOT_EQUIVALENT（誤）— 「SQLite 3.9.0–3.25.x という仮想環境でのみ異なる挙動」を counterexample に使用。D2 に列挙されていない未検証の環境前提を証拠に採用した
- **11433**: NOT_EQUIVALENT → UNKNOWN（誤）— 31 ターン消費後に収束失敗

---

## Exploration Framework カテゴリ：F

> **論文のエラー分析セクションの知見を反映する**

### 選択理由

- カテゴリ A（推論順序）: BL-12（テストソース先読み）, BL-14（逆方向推論）で試行済み・失敗
- カテゴリ B（情報取得）: BL-17（caller/wrapper 探索拡張）, BL-18（削除テスト検索義務）で試行済み・失敗
- カテゴリ C（比較枠組み）: BL-7（CHANGE CHARACTERIZATION）, iter-38（Premise 参照強制）等で試行済み
- カテゴリ D（メタ認知）: BL-9（Trace check 自己評価）で試行済み・失敗
- カテゴリ E（表現改善）: iter-35 自身が Claim テンプレートの文言精緻化を実施済み
- カテゴリ F: **Guardrails セクションへの変更は過去イテレーションで一度も試みられていない**（BL-1〜23 はすべて Certificate テンプレート・Checklist・Definitions・Step 本文への変更であり、Guardrails セクション自体は iter-5 以降一切変更されていない）

論文（Ugare & Chandra, arXiv:2603.01896）の §4.1.1 および design.md で説明されている「未検証前提の採用」が失敗の核心パターンである。現行 Guardrail 6 は「サードパーティライブラリのソース非公開」というケースを扱うが、**実行環境バージョン（データベースバージョン、OS、インタープリタバージョン等）の仮定** は別の未検証前提カテゴリとして未カバーである。これが 13821 の失敗の本質であり、論文の知見の未反映として Category F で対処できる。

---

## 改善仮説（1つ）

**仮説**: 13821 の誤判定は「SQLite 3.9.0–3.25.x」という特定バージョン範囲でのみ異なる挙動を counterexample として使ったことが原因である。この環境前提はリポジトリのテストの skip 条件・fixtures・CI 設定に存在しないにもかかわらず VERIFIED 証拠として扱われた。Guardrail 6 が「ソース非公開の関数挙動の推測を禁止」しているように、**実行環境バージョン固有の挙動の仮定も「未検証前提」として禁止する Guardrail を追加する**ことで、この種の誤判定を防げる。

---

## SKILL.md への変更内容

### 場所

`## Guardrails` → `### From the paper's error analysis` の末尾（現在の項目 6 の直後）に新項目 10 を追加する。

### 追加テキスト（3行）

```
10. **Do not use unverified runtime-environment claims as evidence.** If a behavioral difference between changes is attributed to a specific database version, OS, interpreter version, or library version, that version constraint must be explicitly encoded in the test's skip decorators, setup fixtures, or CI configuration, cited at a specific file:line. A version range or environment assumption that cannot be grounded in the repository is UNVERIFIED and must not determine EQUIVALENT or NOT_EQUIVALENT conclusions.
```

### 変更規模

- 追加行数: 3 行（hard limit 5 行以内に収まる）
- 削除行数: 0 行
- 既存行の変更: なし
- 新規セクション追加: なし（既存 Guardrails セクションへの項目追加のみ）

---

## EQUIV / NOT_EQ の正答率への影響予測

### EQUIV 正答率（現在 8/10 = 80%）

- **13821（改善見込み）**: 「SQLite 3.9.0–3.25.x」のバージョン前提が file:line で検証されなければ UNVERIFIED と判定 → counterexample として使用不可 → 誤った NOT_EQUIVALENT 結論が防がれ、EQUIVALENT に正しく収束する可能性が高い
- **15368（影響なし）**: この case の失敗原因は「削除テストの counterexample 採用」であり、実行環境バージョン仮定とは無関係。本 Guardrail の作用域外
- **その他 EQUIV 8 件（影響なし）**: これらは既に正答しており、環境バージョン仮定を使っていないため変化しない
- **予測**: 80% → 90%（8/10 → 9/10）

### NOT_EQ 正答率（現在 9/10 = 90%）

- Django のテストスイートにおける環境依存テストは、`@skipIf(connection.vendor == 'sqlite')` や `@skipUnlessDBFeature()` 等の skip 条件で明示的に記述されている。これらは file:line で確認可能であり、本 Guardrail の「file:line で検証せよ」という要件を自然に満たす。
- 真の NOT_EQ ケース 9 件で環境バージョン仮定が使われる場合、その仮定はテストの skip 条件か fixtures に存在するはずであり、本 Guardrail は追加の検証行動（該当ファイルを確認する）を要求するだけで判定方向を変えない
- **11433（影響なし）**: 収束失敗（ターン枯渇）が原因。本 Guardrail はターン消費を増やす方向にも減らす方向にも作用しない
- **予測**: 90% → 90%（9/10 で変化なし）

### 全体予測: 85%（17/20）→ 90%（18/20）

---

## failed-approaches.md との照合

### ブラックリスト非該当の確認

| BL | 本提案との関係 |
|----|--------------|
| BL-1（ABSENT 定義追加）| 削除テストを除外する定義変更ではない。環境証拠の品質要件 |
| BL-2（NOT_EQ 証拠閾値引き上げ）| NOT_EQ 全般の閾値を上げていない。環境バージョン限定の証拠品質要件 |
| BL-3（UNKNOWN 禁止）| 無関係 |
| BL-4（早期打ち切り）| 探索を削減しない。むしろ skip 条件の確認という追加検証を要求する |
| BL-5（P3/P4 アサーション記録形式強化）| Premises テンプレートは変更しない |
| BL-7（CHANGE CHARACTERIZATION）| 変更前の中間ラベル生成を要求しない |
| BL-8（Relevant to 列追加）| 受動的記録フィールドの追加ではなく、能動的検証義務（file:line 確認） |
| BL-9（Trace check 自己チェック）| 自己評価精度に依存しない。「file:line が存在するか」は客観的に検証可能 |
| BL-10（Reachability ゲート）| 条件分岐ゲートの追加ではない。Guardrail での証拠品質原則 |
| BL-14（逆方向推論チェックリスト追加）| 非対称な立証責任の引き上げではない（後述） |
| BL-17（caller/wrapper 検索拡張）| relevant test 集合の拡張ではない |
| BL-18（削除テスト検索義務）| **類似性あり**。BL-18 は「削除テストのコールパス確認義務を Checklist に追加」→ 特例探索のサイドクエスト化が失敗原因。本提案は「環境バージョン仮定を使う場合は file:line で検証する」という普遍的な証拠品質原則を Guardrails に追加するものであり、特定症状向けの条件付き探索とは異なる |
| BL-22（テスト削除からの関連性仮定禁止）| BL-22 は D2（Definitions）へのネガティブプロンプト追加。本提案は Guardrails への証拠品質原則追加（変更箇所が異なる） |
| BL-23（nearest consumer 吸収確認義務）| Checklist への特定探索手順追加。本提案は異なる層（Guardrails）への原則追加 |

### 共通原則との照合

| 原則 | 照合結果 |
|------|---------|
| #1 判定の非対称操作 | EQUIV 結論・NOT_EQ 結論の両方に等しく適用（環境バージョン証拠は EQUIV でも NOT_EQ でも file:line 検証が必要）。非対称ではない |
| #2 出力側の制約 | 出力テンプレートを変更しない。証拠収集プロセスを強化する入力側の変更 |
| #3 探索量の削減 | skip 条件・CI 設定ファイルの確認という追加探索を要求。削減ではなく増加方向 |
| #4 同方向の変形 | BL-2 や BL-6 と同一方向ではない。環境証拠の品質要件は NOT_EQ の閾値を一般的に上げるのではなく、特定種類の証拠の validity を問う |
| #5 テンプレートの過剰規定 | Guardrails セクションへの追加。Certificate テンプレートや Step 本文の変更ではない |
| #7 中間ラベル生成のアンカリング | 分析前に変更を分類させない。Guardrail は分析を通じた証拠品質の基準 |
| #8 受動的記録 ≠ 能動的検証 | 「file:line で skip 条件を探す」という能動的検索行動を直接要求する |
| #9 メタ認知自己評価の限界 | file:line が見つかるか否かは客観的に検証可能。精度問題が生じない |
| #14 条件付き特例探索 | 「環境バージョン仮定を使うとき」という条件だが、主比較ループへの直接的な証拠品質強化 |
| #16 ネガティブプロンプトの過剰適応 | 「Do not use X as evidence」という否定形ではあるが、現行 Guardrail 1–9 もすべて "Do not" 形式。Guardrails セクション全体の一貫したパターンに沿っており、特定の推論ルートを一律禁止するのではなく「検証されれば使える（file:line で裏付けがある場合は valid）」という条件付きである |

---

## 変更規模の宣言

- **追加行数**: 3 行（hard limit 5 行以内 ✓）
- **削除行数**: 0 行
- **変更範囲**: `## Guardrails` → `### From the paper's error analysis` セクションの末尾への項目追加のみ
- **新規セクション・テンプレート要素の追加**: なし
