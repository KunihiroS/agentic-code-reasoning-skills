# Iteration 45 — 改善提案（再提出）

> **iter-45 初回却下理由（監査役フィードバック要旨）**:
> 提案が `COUNTEREXAMPLE` の assertion-centric 強化であり、BL-2 / BL-15 / BL-16 の実質再発。
> 変更前との差分で見ると NOT_EQ 側にしか直接作用しない（原則 #1/#6 抵触）。
> 監査役の代替案: **カテゴリ A** — `ANALYSIS OF TEST BEHAVIOR` の各テストで、
> 先に `Observed under Change A/B` を書かせてから PASS/FAIL Claim を書く outcome-first 構造化。

---

## 1. 選択した Exploration Framework のカテゴリと理由

**カテゴリ: A — 推論の順序・構造を変える**

具体的なアプローチ: **`ANALYSIS OF TEST BEHAVIOR` の各テストブロックで、PASS/FAIL Claim を書く前に "Observed under Change A/B" を先に書かせる（outcome-first 構造化）**

### 選択理由

現在の Compare テンプレートは、各テストの分析を次の順序で書かせる:

```
Claim C[N].1: With Change A, this test will [PASS/FAIL]
              because [trace through code — cite file:line]
Claim C[N].2: With Change B, this test will [PASS/FAIL]
              because [trace through code — cite file:line]
Comparison: SAME / DIFFERENT outcome
```

この構造では、エージェントは **先に PASS/FAIL の結論を書き、後からその根拠を添える**。結果として「コード差異を発見 → FAIL と書く → because にその差異を記述」という短絡が構造的に起こりやすい。コードレベルの中間差異がテストの**観測可能な出力**（返り値・例外・状態変化）にまで伝播するかは、この順序では確認しなくても書けてしまう。

**outcome-first 構造**は、この順序を変えることでその短絡を構造的に防ぐ:

```
Observed under Change A: [returned value / raised exception / visible state change — cite file:line]
Observed under Change B: [returned value / raised exception / visible state change — cite file:line]
Claim C[N].1: With Change A, this test will [PASS/FAIL] because [above observation meets/fails the test]
Claim C[N].2: With Change B, this test will [PASS/FAIL] because [above observation meets/fails the test]
Comparison: SAME / DIFFERENT outcome
```

`Observed` を先に書かせることで、エージェントはまず **Change A と Change B がそれぞれテストに何を届けるか** を確定しなければならない。PASS/FAIL はその観測結果から導出されるものになる。

この変更は:
- `ANALYSIS OF TEST BEHAVIOR` の **メインループ** に作用する（COUNTEREXAMPLE 等の最終出力ではない）
- EQUIV / NOT_EQ のどちらの判定経路でも、全テストに対して同じ構造が適用される（対称的）
- assertion 固定にせず、例外・状態変化・副作用も "Observed" に含められる
- 探索の読み順は固定しない（Observed に書く内容を決定するために自由に探索できる）

### カテゴリ A の未試行サブアプローチとしての位置付け

カテゴリ A（推論の順序・構造を変える）の既試行:
- **BL-12 (iter-24)**: テストソースを先に読む探索開始順序の固定 → `Entry:` フィールド追加。**失敗原因**: 「何を読むか」の開始順序を固定したが、テスト入口の記録が目的化し比較推論を強化しなかった
- **BL-14 (iter-28)**: checklist への逆方向推論（Backward Trace）追加。**失敗原因**: NOT_EQ 側にのみ高度な検証を要求する非対称変更だった
- **BL-7 (iter-18)**: 分析前の変更性質の自由記述ステップ追加。**失敗原因**: 中間ラベルがアンカリングバイアスを生んだ

**本提案との差分**:
| 観点 | BL-12 | BL-14 | BL-7 | 本提案 |
|------|-------|-------|------|--------|
| 変更対象 | 探索の開始順序 | checklist（出力後） | 分析前の中間ステップ | 各テスト分析ブロック内の記述順序 |
| 作用箇所 | 探索開始時 | COUNTEREXAMPLE 直前 | ANALYSIS 前 | ANALYSIS の各テストブロック |
| 対称性 | 両方向 | NOT_EQ 側のみ | 両方向 | 両方向 |
| 探索順序固定 | YES | NO | YES | NO |

本提案は「探索の順序」ではなく「推論の記述順序（何を先に書くか）」を変える。これは BL-12 が失敗した「読み始める側のアンカリング」とは異なるメカニズムである。

---

## 2. 改善仮説（1つ）

**`ANALYSIS OF TEST BEHAVIOR` の各テストブロックで、Claim（PASS/FAIL）を書く前に Change A / Change B それぞれの観測結果（Observed）を書かせることで、エージェントがコードレベルの中間差異だけで PASS/FAIL を判断する短絡を構造的に防げる。**

現状の失敗モード（EQUIV 偽陰性）の典型パターン:
1. 変更関数に差異を発見
2. `Claim C[N].1: With Change A, this test will FAIL because [function returns different value]` と書く
3. 差異がテストの観測対象（アサートしている値・捕捉している例外・検証している状態）に到達するかを確認しない
4. `Comparison: DIFFERENT` → NOT_EQ と短絡

**変更後のメカニズム**:
1. `Observed under Change A:` を先に書く必要がある → Change A の下でテストが実際に受け取る値・例外・状態を確定しなければならない
2. `Observed under Change B:` を書く → Change B の下での対応する観測結果を確定
3. **両 Observed が同じ場合**: `Claim C[N].1: PASS` / `Claim C[N].2: PASS` / `Comparison: SAME` → EQUIV に正しく判定
4. **両 Observed が異なる場合**: その差がアサーション境界に到達することが `Observed` に既に記述されているため、`Comparison: DIFFERENT` は観測結果に基づく正当な判定

---

## 3. SKILL.md のどこをどう変えるか（具体的な変更内容）

### 変更箇所

`## Compare` → `### Certificate template` → `ANALYSIS OF TEST BEHAVIOR` セクション内の「For each relevant test:」ブロック（5行）を7行に更新。

### 変更前

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後

```
For each relevant test:
  Test: [name]
  Observed under Change A: [returned value / raised exception / visible state change — cite file:line]
  Observed under Change B: [returned value / raised exception / visible state change — cite file:line]
  Claim C[N].1: With Change A, this test will [PASS/FAIL] because [above observation meets or fails the test]
  Claim C[N].2: With Change B, this test will [PASS/FAIL] because [above observation meets or fails the test]
  Comparison: SAME / DIFFERENT outcome
```

### 変更の要点

| 変更点 | 変更前 | 変更後 | 狙い |
|--------|--------|--------|------|
| Observed 行の追加 | なし | `Observed under Change A/B: [outcome — cite file:line]` | PASS/FAIL を書く前に観測結果を確定させる |
| Claims の前置条件 | なし（自由に PASS/FAIL を宣言可能） | Observed に基づいて PASS/FAIL を導出 | 中間コード差異からの直接ジャンプを遮断 |
| because 節のゴール | `[trace through code]`（コードパス記述） | `[above observation meets or fails the test]`（観測結果との接続） | トレースの終点を観測結果に明確化 |

変更規模: 5行 → 7行（+2行、既存2行を改変）

---

## 4. EQUIV と NOT_EQ の正答率への予測影響

### EQUIV（現在 6/10 = 60%）

**改善見込み: +2〜3ケース**

EQUIV 偽陰性（15368, 11179, 13821, 15382, 12276）の共通パターン: 変更関数に差異を発見 → テストの観測対象への伝播を確認せず NOT_EQ と短絡。

変更後: `Observed under Change A` を書く段階で、エージェントは変更がテストに届ける値・例外・状態を確定しなければならない。コードレベルで差異があっても観測対象で収束するケース（例: 内部実装差異がテストの期待する戻り値に影響しない）では、両 Observed が同じになり `Comparison: SAME` → EQUIV に正しく判定できる。

### NOT_EQ（現在 7/10 = 70%）

**回帰リスク: 低**

真の NOT_EQ ケースでは Change A と Change B が異なる観測結果を届けるため、`Observed A ≠ Observed B` が明示的に記録され、`Comparison: DIFFERENT` はより確かな根拠に基づく判定になる。UNKNOWN（ターン枯渇）への流出リスクも、Observed の記述自体は1行で完了するため最小限。

### 全体予測

| カテゴリ | 現在 | 予測 |
|----------|------|------|
| EQUIV（10件） | 6/10 | 8〜9/10 |
| NOT_EQ（10件） | 7/10 | 7/10 |
| 全体 | 13/20（65%） | 15〜16/20（75〜80%） |

---

## 5. failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| ブラックリスト | 照合結果 |
|----------------|---------|
| BL-2（NOT_EQ 証拠閾値引き上げ） | **非抵触**: 本変更は PASS/FAIL 判定の基準を変えない。観測結果の記述順序を変えることで、既存の Claim / Comparison の構造に作用する。NOT_EQ の立証責任を引き上げるのではなく、Claim 前の観測確定を EQUIV / NOT_EQ に対称的に課す。 |
| BL-7（分析前の中間ラベル生成） | **非抵触**: `Observed` は ANALYSIS 内の各テストブロックで書く（分析の一部）。分析前の変更性質ラベルではなく、各テストの具体的な観測結果記述であり、アンカリングバイアスを生むラベルカテゴリではない。 |
| BL-8（受動的記録フィールドの追加） | **非抵触**: `Observed under Change A: [returned value / raised exception / visible state change — cite file:line]` はコードをトレースして観測結果を確定する能動的な検証行動を必要とする。BL-8 で問題となった「受動的な関係性記述列」とは異なる。 |
| BL-12（テストソース先読みによる固定順序化） | **非抵触**: BL-12 の失敗は「探索の開始順序（どちら側から読むか）」の固定にあった。本変更は「推論の記述順序（何を先に書くか）」を変えるものであり、探索の読み順は自由に保たれる。 |
| BL-14（逆方向推論の非対称追加） | **非抵触**: BL-14 は NOT_EQ のみに高度な検証を要求した。本変更の `Observed` は全テスト・全判定経路に対称的に適用される。 |
| BL-15（COUNTEREXAMPLE 文言変更） | **非抵触**: 本変更は `COUNTEREXAMPLE` セクションを変更しない。`ANALYSIS OF TEST BEHAVIOR` のメインループを変更する。 |
| BL-16（Comparison 直前への first observation point 注釈） | **非抵触**: BL-16 は `Comparison:` の直前（Claims の後）に観測点の型分類注釈を追加した。本変更は Claims の前に `Observed` を置く（Claims の前置条件として）。作用タイミングが逆であり、BL-16 の失敗原因「出力直前の判定姿勢アドバイス」とは構造的に異なる。 |

### 共通原則との照合

| 原則 | 評価 |
|------|------|
| #1（判定の非対称操作） | ✅ `Observed under Change A/B` は EQUIV / NOT_EQ 両方向に対称的に適用。EQUIV を主張するときも NOT_EQ を主張するときも、全テストの Observed を書く義務がある。 |
| #2（出力側の制約は効果がない） | ✅ `ANALYSIS OF TEST BEHAVIOR` のメインループの記述構造変更であり、最終出力（COUNTEREXAMPLE / FORMAL CONCLUSION）の文言変更ではない。 |
| #3（探索量の削減は有害） | ✅ 探索量を削減しない。Observed を確定するために追加のコードトレースが促進される。 |
| #5（入力テンプレートの過剰規定） | ✅ 「何を記録するか」の規定拡張ではなく「記述順序」の変更。観測結果の型（値・例外・状態変化）はあくまで例示であり、assertion 固定のような視野狭窄にならない。 |
| #6（対称化の実効差分） | ✅ 変更前との差分は「全テストブロックに Observed 行が追加される」であり、EQUIV/NOT_EQ 両経路に同等に適用される。既存制約との差分が一方向にのみ作用しない。 |
| #8（受動的記録フィールドは検証を誘発しない） | ✅ `Observed: [returned value / raised exception / visible state change — cite file:line]` は具体的な観測結果の確定を要求する。file:line 引用と具体的な観測値の記述は、コードトレースの実行を誘発する構造的記述。 |
| #11（探索順序の固定は偏りを生む） | ✅ 探索の読み順は固定しない。Observed に書く内容を確定するための探索はエージェントが自由に行える。 |

---

## 6. 変更規模

- **変更対象**: `## Compare` → `### Certificate template` → `ANALYSIS OF TEST BEHAVIOR` → `For each relevant test:` ブロック
- **変更行数**: 2行追加 + 既存2行改変 = **合計4行以内の差分**
- **新セクション追加**: なし
- **削除**: なし
- **20行以内の目安**: ✅ 大幅に以内

---

## 7. 補足：BL-16 との構造的差異の整理

BL-16（iter-30）と本提案はどちらも「観測結果を Comparison に先立てる」という直感を共有するが、作用点が根本的に異なる:

| 観点 | BL-16（失敗） | 本提案 |
|------|--------------|--------|
| **変更箇所** | `Comparison:` の直前（Claims の後） | `Claim C[N].1` の前（Observed が先行） |
| **作用タイミング** | Claims を書き終えた後、Comparison を書く前 | Claims を書く前 |
| **構造的役割** | 出力直前の「比較姿勢の調整アドバイス」 | Claim の前置条件（観測結果が確定してから Claim を書く） |
| **失敗原因** | 「出力直前の判定姿勢アドバイス」は探索行動を増やさない（原則 #2） | 原則 #2 に非抵触: Observed はメインループ内の能動的記述 |

BL-16 は「Comparison を書くとき、観測点を意識せよ」という事後アドバイスだった。本提案は「Claim を書く前に、観測結果を確定せよ」という事前構造である。
