# Iteration 35 — 改善案提案（差し戻し後再提案）

## 1. 前回却下の要約と今回の方針転換

### 却下理由
前回の提案（Compare チェックリスト5番目の項目を「before concluding it has no impact」から「before concluding it changes the test outcome」に置き換え）は、以下の理由で承認不可となった：
- 現行文は **EQUIV 側の安易な「無影響」判断を抑えるガード**であるのに対し、提案文は **NOT_EQ 側の立証責任を引き上げるガード**への置き換えである
- 実効差分は「EQUIV 側ガードを外して NOT_EQ 側ガードへ移す」一方向変更であり、BL-2 / BL-6 / BL-14・共通原則 #1 #4 #6 #12 に実質抵触する

### 今回の方針
監査役の推薦に従い、**カテゴリ C（比較の枠組みを変える）の未試行サブメカニズム**として、**CONTRACT DELTA**（Change A と Change B の外部可観測契約を同一フォーマットで並列比較するセクション）を Compare テンプレートに追加する。

---

## 2. 選択した Exploration Framework カテゴリ

**カテゴリ C: 比較の枠組みを変える**

### 既試行のカテゴリ C 系との差分

| 過去の試行 | 機構 | 今回との違い |
|---|---|---|
| BL-7 (iter-6) | 変更性質を「production/test/both」でラベル付け（判定方向と相関するラベル） | 今回はラベルではなく、A/B それぞれの observable behavior を同形式で記述し対称的に比較する |
| BL-16 (iter-30) | `Comparison:` 直前に観測点リストを注釈（出力フレームの局所変更） | 今回は ANALYSIS OF TEST BEHAVIOR の前処理として独立したセクションを追加（出力フレームを変えない） |
| iter-34 CONTRACT SURVEY（未コミット、benchmark のみ） | 各シンボルに「Contract:（A/B 共通記述）」と「Diff scope: could alter?（推測）」 | 今回は A と B を**別行・同一フォーマット**で記述し、「Delta:（A ≠ B か SAME かの確定判断）」を要求する |

**iter-34 CONTRACT SURVEY との核心的差分**: CONTRACT SURVEY は両パッチを共通の "Contract:" 1 行で記述し、「Diff scope: which could this diff alter?」という**推測**を記入する形だった。エージェントは `Diff scope: return value affected` と書いても、A と B で return value が実際に同じになりえるかを確認しないまま ANALYSIS に進める。今回は A と B を別行で同じ形式で書かせることで、「Change A return ≡ Change B return」を確認した上で `Delta: SAME` と書く = 明確な EQUIV 証拠を生成させる。

---

## 3. 現状の失敗パターン分析

**現スコア: 75%（15/20）**（iter-34 CONTRACT SURVEY の benchmark 結果に基づく）

| カテゴリ | 正答数 | 正答率 |
|---|---|---|
| EQUIV | 6/10 | 60% |
| NOT_EQ | 9/10 | 90% |
| 全体 | 15/20 | 75% |

**失敗ケース:**

| ケース | 正解 | 予測 | 失敗パターン |
|---|---|---|---|
| django__django-15368 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陰性 |
| django__django-11179 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陰性 |
| django__django-13821 | EQUIVALENT | NOT_EQUIVALENT | EQUIV 偽陰性 |
| django__django-15382 | EQUIVALENT | UNKNOWN | EQUIV 収束失敗 |
| django__django-14787 | NOT_EQUIVALENT | UNKNOWN | NOT_EQ 収束失敗 |

### 根本問題：A/B を並列比較する場がない

現行テンプレートの PREMISES は `P1: Change A modifies ...`・`P2: Change B modifies ...` と別々に記述するだけで、変更されたシンボルごとに「A の observable behavior と B の observable behavior が同じか異なるか」を対称的に比較するステップがない。エージェントは次の短絡を取りやすい：

1. コード差異をスキャン → 差異発見
2. 「この関数の return value が変わりうる」と推論（推測）
3. `Comparison: DIFFERENT` と即断（A/B で return value が実際に異なるかを対称的に確認しない）

CONTRACT DELTA はこの短絡を防ぐ：各シンボルで `Change A observable:` と `Change B observable:` を同一フォーマットで埋めることで、「A は X を返す、B も X を返す → Delta: SAME」という**明示的な対称比較**が強制される。

---

## 4. 改善仮説

**仮説**: Compare テンプレートの PREMISES と ANALYSIS OF TEST BEHAVIOR の間に CONTRACT DELTA セクションを追加し、各変更シンボルについて Change A / Change B の外部可観測契約（return / raises / mutates / emits）を同一フォーマットで別行記述させ、`Delta:（A ≠ B な次元、または SAME）` を明示させることで：

1. **EQUIV 偽陰性の抑制**: `Change A observable: return X` と `Change B observable: return X` が同じなら `Delta: SAME` → このシンボルに関してテスト結果は変わらないという**決定論的なシグナル**を生成できる。現状の「コード差異発見 → DIFFERENT 即断」の短絡を防ぐ。

2. **NOT_EQ UNKNOWN の緩和**: `Delta: return value differs` のように明示されると、その次元を assert するテストへ探索を絞り込める。「どのテストを探せばよいか」が明確になり、31 ターン内の収束を助ける。

3. **判定の対称性**: EQUIV では「内部差分はあるが contract は同じ → Delta: SAME」を表しやすく、NOT_EQ では「contract が異なる → Delta: return differs」を同じ粒度で示せる。どちらの判定方向にも同等に機能する。

---

## 5. SKILL.md の変更内容

**変更箇所**: Compare テンプレート、PREMISES と ANALYSIS OF TEST BEHAVIOR の間に新セクションを挿入

**変更前（現行 SKILL.md 164〜167行付近）:**
```
P4: The pass-to-pass tests check [specific behavior, if relevant]

ANALYSIS OF TEST BEHAVIOR:
```

**変更後:**
```
P4: The pass-to-pass tests check [specific behavior, if relevant]

CONTRACT DELTA (one entry per changed symbol):
  Symbol: [name]
  Change A — observable: return [semantics at file:line]; raises [exception or NONE]; mutates [state or NONE]; emits [call or NONE]
  Change B — observable: return [semantics at file:line]; raises [exception or NONE]; mutates [state or NONE]; emits [call or NONE]
  Delta: [dimension(s) where A ≠ B — or SAME if no observable dimension differs]
  Test focus: tests that assert the Delta dimension(s)

ANALYSIS OF TEST BEHAVIOR:
```

### 変更規模

- 追加: 7行（新セクション）
- 変更: 0行（既存の行は変更しない）
- 削除: 0行
- 既存チェックリスト item 5（"before concluding it has no impact"）は**変更しない**

### 各フィールドの意図

| フィールド | 意図 |
|---|---|
| `Symbol:` | どのシンボルの比較かを明示 |
| `Change A — observable:` | パッチ A でのシンボルの observable behavior（file:line 引用で実コード読取を強制） |
| `Change B — observable:` | パッチ B でのシンボルの observable behavior（同上） |
| `Delta: SAME / [dimension]` | A と B で observable behavior が同一か異なるかの**決定論的判断**。SAME なら EQUIV の強い根拠 |
| `Test focus:` | Delta で異なる次元を assert するテストへの探索フォーカス |

---

## 6. EQUIV / NOT_EQ の両方の正答率への影響予測

### EQUIV（現状 60% → 予測 70〜80%）

**改善メカニズム:**
- `Change A observable:` と `Change B observable:` を並べて書くことで、「A も B も同じ値を返す → Delta: SAME」という明示的な確認ステップが生まれる
- `Delta: SAME` はテスト分析より前に「このシンボルはテスト結果に差をもたらさない」という証拠を確定させ、ANALYSIS でのコード差異→DIFFERENT 短絡を防ぐ
- 特に「内部実装は異なるが observable behavior は同じ」パターン（EQUIV 偽陰性の典型）で効果が期待できる

### NOT_EQ（現状 90% → 予測 85〜90%）

**リスク管理:**
- 本変更は既存の checklist item 5（"before concluding it has no impact"）を**変更しない** → EQUIV 側の既存ガードを維持
- NOT_EQ 側に「判定前の追加証明義務」を課さない（BL-2/BL-14 との差異）
- `Delta: return differs` は NOT_EQ の証明ではなく探索フォーカスの情報として機能
- CONTRACT DELTA の記入オーバーヘッド（5行/シンボル）がターン消費を若干増加させるリスクはある
- 対策: 変更シンボルが少ないケースが多いため、1〜2 シンボル × 5行 ≒ 5〜10行の追加負荷に留まる

### 全体予測

現状 75%（EQUIV 6/10 + NOT_EQ 9/10）  
予測 80〜85%（EQUIV 7〜8/10 + NOT_EQ 8〜9/10）

---

## 7. failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| ブラックリスト | 本案との違い |
|---|---|
| BL-2: NOT_EQ 証拠閾値引き上げ | 本案は NOT_EQ の立証責任を増やさない。CONTRACT DELTA は判定前の追加証明要求ではなく、A/B 対称な事実確認ステップ |
| BL-6: 対称化の実効差分が片側 | 本案は A/B 両行を同形式で記述する真の対称変更。既存 checklist item 5 を変更しないため、差分は「A/B 対称な前処理セクションの追加」のみ |
| BL-7: 判定方向と相関するラベル生成 | `Delta: SAME / return differs` はテスト結果への影響（EQUIV/NOT_EQ）を直接示さない。return が differs でも assert するテストがなければ EQUIV になりうる |
| BL-8: 受動的記録フィールド | `Change A/B observable:` は file:line 参照を必須とし、実際のコード読取を要求する能動的フィールド |
| BL-14: DIFFERENT 主張時の追加検証 | 本案は「特定の結論を出す前に追加検証」という条件付き要件ではない。両パッチを同形式で記述する対称的な前処理 |
| BL-16: Comparison: 直前の観測点注釈 | 本案は ANALYSIS OF TEST BEHAVIOR の前処理セクション。Comparison: フィールド自体は変更しない |

**結論: いずれのブラックリスト項目とも実質的に異なる。**

### 共通原則照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | **問題なし**: Change A / Change B の同形式記述は完全に対称。Delta: SAME も Delta: return differs も片側有利ではない |
| #2 出力側の制約 | **問題なし**: 前処理セクションの追加（入力側）。出力テンプレートを変更しない |
| #3 探索量の削減 | **問題なし**: 削減しない。Test focus は探索ターゲットを示すが、追加コード読取（file:line）を要求する |
| #4 同じ方向・異なる表現 | **問題なし**: iter-34 との差分は「共通 Contract → A/B 別行」「could alter 推測 → Delta 決定論的」。方向転換 |
| #5 入力テンプレートの過剰規定 | **軽微リスク**: return / raises / mutates / emits の 4 次元はカバレッジが広く、over-specification リスクは低い |
| #6 対称化の実効差分 | **問題なし**: 既存 checklist item 5 は変更しない。変更前との差分は「A/B 対称な 5 行セクションの追加」のみ |
| #8 受動的記録フィールド | **問題なし**: file:line 参照により能動的コード読取を要求 |
| #12 アドバイザリな非対称指示 | **問題なし**: 非対称指示なし。A も B も同じ形式で義務 |

---

## 8. 変更規模

- **追加**: 7行（新セクション CONTRACT DELTA）
- **変更**: 0行（既存の行は一切変更しない）
- **削除**: 0行
- **目安（20行以内）**: ✅ 満たす

---

## 9. 研究コア構造との整合性確認

| コア要素 | 影響 |
|---|---|
| 番号付き前提（Numbered premises） | 変更なし（P1〜P4 は維持） |
| 仮説駆動探索（Hypothesis-driven exploration） | 変更なし |
| 手続き間トレース（Interprocedural tracing） | 変更なし（CONTRACT DELTA はトレーステーブルとは独立した前処理） |
| 必須反証（Mandatory refutation） | 変更なし（COUNTEREXAMPLE / NO COUNTEREXAMPLE EXISTS は維持） |

変更は PREMISES と ANALYSIS の間に前処理セクションを追加するのみ。研究のコア構造は完全に維持される。
