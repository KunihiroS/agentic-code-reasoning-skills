# Iteration 33 — 改善案（再提案）

## 選択した Exploration Framework カテゴリ

**カテゴリ B: 情報の取得方法を改善する**

### 選択理由

監査フィードバックで「代替案: カテゴリ B — relevant test 発見の優先順位を改善するが、探索範囲は広げない」が明示的に提示された。具体的には「変更差分が最終的に feeding する公開 API / return value / raised exception を直接 assert している最近接テスト」を優先して読む方向を推奨している。

過去のカテゴリ B 試行との対応:

| 試行済み BL | メカニズム | 失敗の本質 |
|------------|-----------|-----------|
| BL-5 | P3/P4 に assertion 形式を規定 | 前提テンプレートの視野固定（原則 #5） |
| BL-8 | Step 4 に `Relevant to` 列を追加 | 受動的記録フィールド（原則 #8） |
| BL-12 | `Entry:` フィールド + テストソース先読み固定順 | 探索開始側へのアンカリング（原則 #11） |
| BL-13 | `Key value` データフロー欄の追加 | 受動的記録 + 視野圧縮（原則 #5/#8） |
| BL-17 | caller/wrapper/helper まで検索スコープ拡張 | relevant test 集合の低精度拡張（原則 #13） |

**今回提案のメカニズム**: 検索スコープは拡張せず（BL-17 と異なる）、既に発見した relevant tests の中で **どのテストを優先して読むか** を意味論的な基準で決める。新たな記録フィールドを追加しない（BL-5/BL-8/BL-12/BL-13 と異なる）。探索の開始点を固定しない（BL-12 と異なる）。

---

## 改善仮説

**仮説**: D2 で複数の relevant test が見つかった際に「変更の主たる出力（return value、raised exception、直接変更される attribute）を最初にアサートするテスト」を優先して読む指示を追加することで、エージェントが変更とテスト結論の最短の因果連鎖を最初に評価するようになり、コード差分発見後にアサーションまで追跡する前に NOT_EQ と結論するショートカットが減少する。

### なぜ priority 指示が有効か

現行の D2 は「変更されたシンボルを参照するテストを検索せよ」と指示するのみで、複数テストが見つかった場合のどれを先に読むかは非決定である。エージェントが偶然に変更コードを参照するだけで assertion まで遠いテストを先に読んだ場合、コード差分発見→テスト失敗という推論ジャンプが起きやすい。

一方、変更の primary output を直接 assert するテストを最初に読めば:
- **True NOT_EQ**: そのテストが最も決定的な証拠を持つ → NOT_EQ をより確実に確認できる
- **True EQUIV**: そのテストが変更の出力が等しいことを最初に示す → EQUIV の根拠が最初から確立される
- **False NOT_EQ（現状の失敗パターン）**: コード差分はあっても、primary output を assert するテストを先に読むことで「assertion レベルでは等しい」とわかり、誤判定が防止される

### 他の失敗原則との相違

- **原則 #1（非対称操作）**: D2 の priority 指示は EQUIV / NOT_EQ 両判定に対して対称に作用する（判定の前にテストを読む順序に過ぎない）
- **原則 #11（探索順序の固定）**: BL-12 が「テスト side を先に読め」という側への固定だったのに対し、今回は「どのテストから読むか」を意味論的基準（assertion の観測対象）で決める。固定対象が探索の開始側（test vs code）ではなく、テスト集合内の選択順序であり、かつその基準が比較の核心（change の primary output）と整合している
- **原則 #13（スコープ拡張は有害）**: 検索スコープを変えずに読む順序のみを変えるため、relevant test 集合の精度は低下しない

---

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の Certificate template の **DEFINITIONS D2** ブロック。具体的には `To identify them:` の文の後（`If the test suite is not provided` の前）に 2 文を追加する。

### 変更前（既存）

```
D2: The relevant tests are:
    (a) Fail-to-pass tests: tests that fail on the unpatched code and are
        expected to pass after the fix — always relevant.
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
    To identify them: search for tests referencing the changed function, class,
    or variable. If the test suite is not provided, state this as a constraint
    in P[N] and restrict the scope of D1 accordingly.
```

### 変更後（提案）

```
D2: The relevant tests are:
    (a) Fail-to-pass tests: tests that fail on the unpatched code and are
        expected to pass after the fix — always relevant.
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
    To identify them: search for tests referencing the changed function, class,
    or variable. When multiple tests are found, read first those whose
    assertions directly observe the change's primary output — its return value,
    raised exception, or directly modified attribute — before tests that only
    transitively invoke the changed code through intermediate layers. Do not
    expand the search to callers or wrappers not referenced by tests.
    If the test suite is not provided, state this as a constraint
    in P[N] and restrict the scope of D1 accordingly.
```

**変更規模**: 追加 4 行（約 45 語）、変更・削除 0。合計変更量は 20 行以内。

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV 正答率（現状 7/10 = 70%）

**予測: 8〜9/10（+1〜2件）に改善**

失敗している 3 件（15368, 13821, 15382）は「コード差分を発見 → アサーションまで追跡せずに NOT_EQ 結論」パターンである。Primary output を assert するテストを最初に読めば、そのテストのアサーションが Change A / B 両方で同じ結果を示すことがわかり、NOT_EQ の証拠が得られなくなる。これにより誤判定が修正される可能性が高い。

### NOT_EQ 正答率（現状 10/10 = 100%）

**予測: 10/10 維持**

現在 NOT_EQ を正しく判定している 10 件では、エージェントは既に最終的なアサーション差異に到達した上で判定している。Priority 指示はその到達を「最初に読むテスト」で行うよう促すだけであり、到達自体を妨げない。むしろ最も決定的な証拠を持つテストが最初に読まれるため、NOT_EQ の確信度が向上する可能性がある。

---

## failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL番号 | 内容 | 本提案との相違 |
|--------|------|---------------|
| BL-5 | P3/P4 に assertion 条件の記録形式を規定 | 本提案は D2 の読む順序の指示（記録テンプレートの変更なし）。前提フィールドへの制約を加えない |
| BL-8 | Step 4 に `Relevant to` 列を追加 | 本提案は新しい記録フィールドを追加しない。探索行動の優先順位を変えるのみ |
| BL-12 | `Entry:` フィールドで test entry 先読みを固定 | 本提案は新フィールドを追加しない。また固定の向き（test 側 vs code 側）ではなく、どのテストを先に読むかの意味論的基準 |
| BL-13 | `Key value` データフロー欄の追加 | 本提案は記録欄を追加しない。変数への圧縮や代理表現も行わない |
| BL-17 | caller/wrapper/helper まで検索スコープ拡張 | 本提案は検索スコープを拡張しない。明示的に「callers や wrappers へ拡張しない」と指定する |

### 共通原則照合

| 原則 | 判定 | 理由 |
|------|------|------|
| #1 判定の非対称操作 | ✅ 適合 | D2 の変更は EQUIV / NOT_EQ 両判定の前段（テスト読み取り順序）に作用。判定方向に対して対称 |
| #2 出力側の制約は効果がない | ✅ 適合 | 変更は出力テンプレートではなく、テスト発見・読み取りという入力側の探索行動を改善する |
| #3 探索量の削減は常に有害 | ✅ 適合 | priority 指示は「最初に読む」であり「それだけ読む」ではない。探索量は変わらない |
| #5 入力テンプレートの過剰規定 | ✅ 適合 | D2 に意味論的な優先基準を追加するが、記録する情報の形式は規定しない。視野を狭めない |
| #8 受動的記録フィールド | ✅ 適合 | 新しい記録フィールドを追加しない。読む順序の指針のみ |
| #11 探索順序の固定 | ✅ 適合 | BL-12 は「test side を先に読め」という side への固定。本提案は「観測力の高いテストから読め」という意味論的基準であり、探索の往復構造を崩さない |
| #13 relevant test 集合の低精度な拡張 | ✅ 適合 | スコープを拡張しない。「callers や wrappers へ拡張しない」を明示して BL-17 の再発を防ぐ |

---

## 変更規模

- 追加行数: **4行**
- 削除行数: **0行**
- 変更場所: SKILL.md `## Compare` → Certificate template → DEFINITIONS D2
- 合計: **4行（20行以内の制限に対して最小限）**
