# Iteration 43 — 改善案提案（iter-42 再提案）

> **iter-42 却下理由**: 提案は `Asserts:` フィールドの追加という assertion-centric なテンプレート変更であり、
> BL-5 / BL-8 / BL-11 / BL-14 / BL-16 の実質再発と判定された。assertion 固定が視野狭窄を招き、
> NOT_EQ 側の立証負荷を増やす方向に作用するリスクが高い。
> 監査役の代替案: **カテゴリ F** で「原論文の verified behavior 志向を `because` 節に強める。
> Claim で引用する関数の実定義を読み、その test input への effect を 1 行で verified に記録する。
> 対象は Claim に実際に引用する関数のみ。テーブル全面拡張はしない」。

---

## 1. 選択した Exploration Framework カテゴリ

**カテゴリ F: 原論文の未活用アイデアを導入する**

具体的サブアプローチ: 「原論文の VERIFIED behavior 要求を Compare Claim の `because` 節に適用する」

### 選択理由

原論文 (Ugare & Chandra, arXiv:2603.01896) のコアメカニズムは **VERIFIED** 証拠の要求である。
現行 SKILL.md の Step 4 トレーステーブルには「Read the actual definition. Do not infer behavior from the name.
Mark the Behavior column VERIFIED only after reading the source.」という要求がある。

しかし Compare テンプレートの Claim `because` 節には:
```
because [trace through code — cite file:line]
```
とあるだけで、**cited された関数について「実定義を読みその test input への verified effect を記録する」
という明示的な要求がない**。エージェントは `because` 節に関数名と差分要約だけを書き（例:「X はケース A では Y を返す」）、
その関数の実定義を test-specific input で確認せずに Claim を確定できてしまう。

これが EQUIV 偽陰性（15368, 15382）の根本原因である:
1. 変更関数 X でコード差分を発見
2. `because X returns different value` と書く（実定義確認なし、test input への effect 確認なし）
3. Comparison: DIFFERENT → NOT_EQ と短絡

原論文の「verified behavior」原則は Step 4 テーブルには適用されているが、
**Compare Claim の `because` 節には引き継がれていない**。これが未活用の論文アイデアである。

### 過去試行との差分

カテゴリ F の既試行:
- **iter-38（F）**: `because` 節を「P[N] の期待動作を満たす/違反するかを示す」形に変更 → 80%
  - 差異: P[N] への抽象的な接続を要求。test-specific inputs への concrete effect を要求しない
- **iter-39（F）**: checklist に「immediate caller を読む」を追加 → 70%
  - 差異: チェックリスト項目。方向（upward caller）が固定。`because` 節の形式は変えない
- **iter-40（F）**: EDGE CASES を `because` 節に統合 → 65%（BL-19）
  - 差異: branch coverage 義務の移植。verified definition 要求ではなく coverage 義務

**本提案の差分**:「cited された関数について実定義を読み、この test の具体的な inputs への
verified effect を記録する」という **証拠の質要件** を `because` 節に追加する。
- 新規フィールド追加なし（BL-8, BL-13, BL-16 との差異）
- assertion 固定なし（BL-5, BL-11, iter-42 との差異）
- 対象は Claim に引用する関数のみ（探索範囲の全面拡張なし → BL-17 との差異）
- 関数名・差分要約でなく test input 固有の verified effect を要求（iter-38, iter-39 との差異）

---

## 2. 改善仮説

**仮説**: Compare テンプレートの `because` 節に「Claim で引用する各関数について、
実定義を読みこの test の具体的な inputs への verified effect を記録する（名前や差分要約を書くのではなく）」
という要件を追加することで:

1. エージェントは関数名や差分の要約を根拠に Claim を書けなくなる
2. 実定義を読んで test-specific inputs への effect を確認しなければ `because` 節を満たせない
3. EQUIV 偽陰性（15368, 15382）では、差分があっても test inputs への effect が同一であることを
   実定義から確認 → Comparison: SAME → EQUIV に正しく判定

この変更は:
- `because` 節の **証拠の質** を上げる（citation から verification へ）
- 引用する関数に限定することで探索スコープを広げない
- Change A / Change B 両側に対称的に適用（非対称性なし）

---

## 3. SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の `### Certificate template` の
`ANALYSIS OF TEST BEHAVIOR` ブロック（fail-to-pass テスト用 + pass-to-pass テスト用）の
`Claim C[N].1 / C[N].2` の `because` 節を変更する。

### 変更前（現状）

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome

For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description]
  Claim C[N].2: With Change B, behavior is [description]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後（提案）

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — for each function cited, read its definition
                and state its verified effect on this test's specific inputs at file:line,
                not merely a summary of the diff]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — for each function cited, read its definition
                and state its verified effect on this test's specific inputs at file:line,
                not merely a summary of the diff]
  Comparison: SAME / DIFFERENT outcome

For pass-to-pass tests (if changes could affect them differently):
  Test: [name]
  Claim C[N].1: With Change A, behavior is [description — verified at file:line]
  Claim C[N].2: With Change B, behavior is [description — verified at file:line]
  Comparison: SAME / DIFFERENT outcome
```

**変更規模**: fail-to-pass Claim ×2 行修正（各 `because` 節に内容追加）、
pass-to-pass Claim ×2 行修正（`verified at file:line` 追加）。計 4 行修正。

---

## 4. EQUIV と NOT_EQ 両方の正答率への予測影響

### EQUIV（現状 8/10 = 80%）

**15368, 15382（EQUIV 偽陰性）の改善メカニズム**:

現在の失敗パターン:
- エージェントが変更関数 X のコード差分を発見し、`because X returns different value (cite X:line)` と書く
- 実際には、X の定義を test 固有の inputs で追うと effect が同一（差分が test inputs に到達しない）
- しかし `cite file:line` だけでは関数定義の読み取りを要求していないため、
  エージェントは「差分があるから FAIL」と短絡できてしまう

新しい要件「for each function cited, read its definition and state its verified effect on this test's specific inputs」:
- エージェントは `because` 節を満たすために実際に X の定義を読まなければならない
- X の定義を test-specific inputs で確認すると effect が同一と判明 → Claim: PASS → Comparison: SAME → EQUIV

**予測: +1〜2 改善（8/10 → 9〜10/10）**

### NOT_EQ（現状 9/10 = 90%）

**真の NOT_EQ ケースへの作用**:

- 変更関数 X の実定義を test inputs で確認すると effect が異なる → Claim: FAIL / PASS の差 → DIFFERENT → NOT_EQ
- 追加コスト: per-function の定義確認。しかし Claim に already 引用している関数のみが対象
  （全関数のテーブル拡張ではない）
- **14122（UNKNOWN）**: ターン枯渇が主因。本変更は Claim に引用済み関数の verification であり、
  新規探索の追加ではない。影響軽微と判断

**予測: 0〜-1 変化（9/10 → 8〜9/10）**

### 総合予測

- 現状: 17/20（85%）
- 期待: 18〜19/20（90〜95%）

---

## 5. failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|---------------|
| BL-5 | P3/P4 にアサーション形式を追加 | **差異あり**: assertion 行を前提セクションで記録。本提案は assertion ではなく cited 関数の verified effect（exception / side-effect / return value 含む）を `because` 節で要求 |
| BL-8 | トレーステーブルに `Relevant to` 列追加（受動的記録） | **差異あり**: 新規フィールド追加。本提案は**既存 `because` 節の証拠の質要件変更**。新フィールド追加なし |
| BL-11 | ANALYSIS に outcome mechanism 注釈追加 | **差異あり**: `Comparison:` 後の注釈（フレーミング）。本提案は `because` 節の evidence quality 要件 |
| BL-13 | `Key value` データフロートレース欄の追加 | **差異あり**: 新規フィールド構造で変数選択を要求。本提案は新フィールドなし、変数選択不要（cited 関数の effect） |
| BL-14 | DIFFERENT 結論のみに backward trace 要求（非対称） | **差異あり**: NOT_EQ 結論時のみ要求（非対称）。本提案は Change A / B 両 Claim に同一要件（対称） |
| BL-16 | `Comparison:` 直前への first observation point 注釈 | **差異あり**: Comparison: 直前の出力フレーミング。本提案は `because` 節の入力証拠の質要件 |
| iter-38 | `because` 節に P[N] クロスリファレンスを追加 | **差異あり**: P[N] への抽象的な接続要求。本提案は cited 関数の test-specific inputs への concrete verified effect 要求 |
| iter-39 | checklist に immediate caller を読む義務を追加 | **差異あり**: チェックリスト項目（方向固定）。本提案は `because` 節の形式変更で方向を固定しない |
| iter-40/BL-19 | EDGE CASES を `because` 節に統合 | **差異あり**: branch coverage 義務の移植。本提案は cited 関数の verified effect 要求（quality 基準の変更） |

### 共通原則との照合

| # | 原則 | 適合状況 |
|---|------|---------|
| #1 | 判定の非対称操作は必ず失敗する | ✅ Change A / B 両方の Claim に同一要件（対称） |
| #2 | 出力側の制約は効果がない | ✅ `because` 節に書く証拠の質要件（入力側） |
| #3 | 探索量の削減は常に有害 | ✅ 証拠の質を上げる方向。Claim に引用する関数の定義確認を要求 |
| #4 | 同方向の変更は表現を変えても同じ結果 | ✅ iter-38/39/40 と異なるメカニズム（verified effect on test inputs） |
| #5 | 入力テンプレートの過剰規定は探索視野を狭める | ✅ assertion に限定しない（effect = exception / side-effect / return value すべてを含む）。Claim に引用する関数への限定により全面展開を防ぐ |
| #6 | 対称化の実効差分で評価 | ✅ 差分は「C[N].1 と C[N].2 両方で cited 関数の verified effect 記録が追加される」。EQUIV/NOT_EQ 双方に同一の追加 |
| #7 | 分析前の中間ラベル生成はアンカリングバイアスを導入する | ✅ ラベル生成ではなく証拠の記録要件 |
| #8 | 受動的記録フィールドは能動的検証を誘発しない | ✅ 新規フィールドを**追加しない**。既存 `because` 節で「実定義を読む」という能動的検証行動を直接要求する |
| #9 | メタ認知的自己チェックは機能しない | ✅ 自己チェックではなく証拠の質要件 |
| #10 | 判別力のないゲートは無効 | ✅ ゲートではなく、常時適用の証拠要件 |
| #11 | 探索順序の固定は探索の偏りを生む | ✅ 読む順序を固定しない。cited 関数の定義を確認するという quality 基準 |
| #12 | アドバイザリな非対称指示も実質的な立証責任の引き上げ | ✅ Change A / B 両 Claim に対称的な要件。非対称指示なし |
| #13 | relevant test 集合の低精度拡張は有害 | ✅ test 集合の変更なし |
| #14 | 条件付きの特例探索は主比較ループを阻害する | ✅ 条件付きではなく、Claim 作成時の常時適用要件 |

### BL-8 との決定的な差異

BL-8 の Fail Core は「記録欄の追加は能動的検証を誘発しない」である。

- BL-8 は **新規フィールドを追加**（トレーステーブルの列）→ 「フィールドを埋める」ことが目的化
- 本提案は **既存 `because` 節の証拠要件を変更** → 「埋める欄が増えた」ではなく「既存証拠の質基準が上がった」
- 具体的には: `cite file:line` → `read its definition and state its verified effect on this test's specific inputs at file:line`
  これは「ファイルの行を引用する」から「定義を読んでその関数がこの input でどう振る舞うかを verified に記録する」への質的な要件変更

### BL-13 との決定的な差異

- BL-13: 「1〜2 の key variable を選定して created/modified/value の chain を記録する」→ 変数選定が新たなアンカー
- 本提案: 「Claim で引用する関数について verified effect を記録する」→ 変数選定という新たなアンカーを導入しない

---

## 6. 変更規模

- **変更行数**: 4 行修正（fail-to-pass 2 行 + pass-to-pass 2 行）
- **新規追加**: 各行内容の拡張（行数増加なし、既存行の置換）
- **削除行数**: 0 行
- **変更箇所**: `## Compare` → `### Certificate template` → `ANALYSIS OF TEST BEHAVIOR` の fail-to-pass / pass-to-pass 両ブロック
- **20 行以内**: ✅ 4 行修正のみ
