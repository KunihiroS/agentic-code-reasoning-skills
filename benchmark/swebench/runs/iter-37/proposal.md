# Iteration 37 — 改善案（差し戻し後再提案）

## 前回提案の却下理由と方針転換

前回提案（`because [trace through changed code to the assertion or exception — cite file:line]`）は以下の理由で却下された：

- **BL-16 / BL-11 / BL-2 系と実質同型**：「assertion or exception までトレースを終端させる」は、観測点アンカリング（BL-16）・outcome mechanism 注釈（BL-11）・NOT_EQ 立証責任引き上げ（BL-2）と同方向
- **実効差分が非対称**：PASS/FAIL 両 Claim に対称的な文言でも、差分は FAIL 側の立証負荷として重く作用する（共通原則 #6）
- **カテゴリ F の新規性不足**：既存失敗（BL-16/11/2 系）の再表現であり、未試行メカニズムとは言いにくい

監査役の推薦に従い、**カテゴリ B（情報の取得方法）** として、「変更差分行からフォワードトレースする」代わりに「テストが読む最終データ依存値から 1 段逆方向に遡る」探索指示を追加する。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ B: 情報の取得方法を改善する**

> 「何を探すかではなく、どう探すか・何を確認してから判断するかを改善する」

### 選択理由

現行の失敗モード（15368, 11179, 13821, 15382）に共通する根本は「コード差異を発見した後、それがテスト結果を変えるかを確認せずに Claim FAIL と書く」ことにある。現在の Compare checklist は「変更差分からテストを通じてフォワードトレースする」ことを指示しており、エージェントは差分行を起点にして「この関数が Y を返す → テストが失敗する」という連鎖をフォワードに構成する。

この方向では、差分と test の間にある「*テストは何の値を実際に比較しているか*」を読まずにスキップしやすい。テストが比較している値（最終データ依存値）を先に特定し、その値が変更によって変わるかを確認する方向（test → 値 → 変更の影響）は、現行とは探索の起点と方向が異なる。

### 過去の Category B 試行との差分確認

| 過去の試行 | 機構 | 今回との違い |
|---|---|---|
| BL-8 (iter-7) | Step 4 テーブルに `Relevant to` 列を追加（受動的記録フィールド） | 今回はフィールド追加ではなく、探索の開始点・方向を変える探索指示 |
| BL-10 (iter-7) | Reachability ゲート（変更コードへの到達確認 YES/NO） | BL-10 は「差分からテストへ到達するか」の YES/NO ゲート。今回は「テストが読む値から変更へ遡る」方向であり、ゲートではなく探索順序の変更 |
| BL-11 (iter-23) | outcome mechanism 注釈（assertion/exception/side effect を記録） | 今回は固定ラベルを使わない。テストごとに「どの値が outcome を決めるか」を読んで特定する |
| BL-12 (iter-25) | テスト先読みによる固定順序化（`Entry:` フィールド追加） | BL-12 は「先にテストの entry point を記録する」フィールド追加。今回は「テストから値の依存元を特定する」探索指示であり、フィールド追加なし |
| BL-13 (iter-26) | `Key value` データフロートレース欄の追加 | BL-13 は新フィールドとして追加し記録させた。今回はフィールド化しない。チェックリストへの探索指示のみ |
| BL-16 (iter-30) | `Comparison:` 直前に first observation point 注釈を追加 | BL-16 は観測点を「テンプレートフィールド」として追加。今回はテンプレートを変えず、checklist の探索指示のみ変更 |

---

## 改善仮説（1つ）

**各 relevant test についてテストソースを読み「テストが pass/fail を決定するために読む・比較するデータ依存値」を先に特定し、その値の生成元を 1 段逆方向に確認してから Claim を書く探索行動を追加することで、コード差異の発見でトレースを打ち切るショートカットが構造的に減り、EQUIV 偽陰性（EQUIV を NOT_EQ と誤判定）を減らせる。**

論拠：現在の失敗パターン（15368, 13821, 15382, 11179）では、エージェントは「Change A と Change B で関数 X が返す値が違う」という*コード差異*を発見し、その差異がテストの比較値に到達するかを確認せずに Claim FAIL と書く。テストが実際に比較している値（例：`assertEqual(response.status_code, 200)` の `response.status_code`）を先に特定すれば、変更が*その値*に影響するかどうかを確認する動機が生まれ、影響しない場合は Claim を PASS に修正できる。

この探索指示は「固定ラベル（assertion/exception）で観測点を指定する」ことなく、テストごとに値を読んで特定するよう要求するため、BL-11/16 のアンカリング問題を回避する。

---

## SKILL.md の変更内容

Compare checklist に探索指示を 1 行追加する。

### 変更前（Compare checklist、再掲）

```
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

### 変更後（追加は 1 行のみ）

```
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- For each relevant test, read the test to identify the data value it reads or compares to determine pass/fail; trace back one step to where that value is produced and verify whether the change affects it before writing a Claim
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

**変更規模：1 行追加のみ。テンプレートフィールド変更なし。新セクション追加なし。**

---

## EQUIV と NOT_EQ の正答率への影響予測

### EQUIV（正答率向上を期待）

失敗パターン：エージェントがコード差異を発見 →「このパスは異なる値を返す」→ Claim FAIL と書く。テストが実際に比較している値を確認しない。

変更後：各 relevant test について「テストが比較する値を読む → その値の生成元を 1 段確認 → 変更がその値に影響するか？」という探索順序が挿入される。EQUIV ケースでは変更が*テストの比較値*に到達しない（またはしても同じ値になる）ため、エージェントがその確認をすれば Claim を PASS に修正しやすくなる。

→ EQUIV 正答率の改善を期待（現在 6/10 → 7〜9/10）

### NOT_EQ（回帰リスク低）

真の NOT_EQ ケースでは、変更がテストの比較値に確かに影響を与えるため、「その値の生成元を 1 段確認」しても NOT_EQ の結論は変わらない。追加探索はテストの比較値を読む 1 ステップであり、既存の探索と矛盾しない。Claim テンプレートを変えないため COUNTEREXAMPLE セクションへの影響もない。

UNKNOWN ケース（14787, 11433, 12663）はターン数超過が原因であり、本変更はそれらの探索コストを増やさない（1 ステップの確認追加のみ）。

→ NOT_EQ 正答率への悪影響なし（現在 7/10 → 維持 or 改善）

---

## failed-approaches.md のブラックリストおよび共通原則との照合

| チェック項目 | 判定 | 理由 |
|---|---|---|
| BL-2（NOT_EQ 閾値厳格化） | ✅ | 今回は立証責任を引き上げない。EQUIV 探索を改善する指示であり、NOT_EQ 専用の証拠要件追加ではない |
| BL-8（受動的記録フィールド） | ✅ | 新フィールド追加なし。チェックリストへの探索指示であり、記録テンプレートを変えない |
| BL-10（Reachability ゲート） | ✅ | ゲート（YES/NO 分岐）ではなく探索指示。弁別力の問題が異なる次元で発生しない |
| BL-11（outcome mechanism 注釈） | ✅ | 固定ラベル（assertion/exception）を使わない。テストごとに実際に値を読んで特定する |
| BL-12（固定順序化） | ✅ | Entry フィールド追加なし。探索の開始点指示のみで、固定の探索順序を義務付けない |
| BL-13（Key value フィールド） | ✅ | フィールド追加なし。探索指示として書く（監査役の推薦通り） |
| BL-16（first observation point） | ✅ | テンプレートフィールド追加なし。Comparison 行は変更しない |
| 共通原則 #1（判定の非対称操作） | ✅ | EQUIV と NOT_EQ の両方向に同一の探索指示。立証責任を一方向に移動させない |
| 共通原則 #3（探索量の削減） | ✅ | 探索を減らさない。テストの比較値を 1 段確認するステップを追加する |
| 共通原則 #5（入力テンプレートの過剰規定） | ✅ | 何を記録するかを規定しない。何を確認するかの探索指示のみ |
| 共通原則 #6（対称化の実効差分） | ✅ | 追加指示は PASS/FAIL 両方向に同様に効く。差分は「テスト比較値の確認を追加」であり一方向に寄らない |
| 共通原則 #8（受動的記録は検証を誘発しない） | ✅ | 記録フィールドではなく探索行動（テストソースを読む・値の生成元を 1 段確認する）を直接要求する |

---

## 変更規模

- 修正行数：0
- 新規追加行数：1（Compare checklist への探索指示 1 行）
- 変更セクション：`Compare checklist`
- 20 行以内：✅ 1 行のみ
