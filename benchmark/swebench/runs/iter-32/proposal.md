# Iteration 32 — 改善案（再提案）

## 選択した Exploration Framework カテゴリ

**カテゴリ B: 情報の取得方法を改善する**

### 選択理由

前回案（カテゴリ F）は監査で却下された。主理由は「既存 Guardrail 5 の compare-specific 言い換えに過ぎない」「変更前との差分が差異発見後の追加確認として NOT_EQ 側に偏る」（BL-6 / BL-14 型再発）。

監査フィードバックが提示した代替方向:
> `compare` の relevant test 特定（D2）で、変更シンボルを直接参照するテストだけでなく、**その caller / wrapper / helper を経由して到達するテストを repo search で拾う**ことを明示し、最初に「最も近い oracle-bearing caller」を優先して追う。

カテゴリ B（証拠の集め方の改善）は、過去のブラックリストとの対応が次のとおり:

| カテゴリ B 試行済み BL | 内容 | 失敗本質 |
|----------------------|------|--------|
| BL-5 | P3/P4 をアサーション記録形式に強化 | 前提テンプレートの視野固定（原則 #5） |
| BL-8 | Step 4 に Relevant to 列を追加 | 受動的記録フィールド（原則 #8） |
| BL-12 | テストソース先読み固定順序 | 探索順序の強制（原則 #11） |
| BL-13 | Key value データフロー欄の追加 | 受動的記録＋視野圧縮（原則 #5/#8） |

今回の提案（D2 の検索スコープ拡張）は、これら試行済み BL のいずれとも異なる。失敗した試行が「何を書くか（記録テンプレート）」「どの順で読むか（探索順序）」を操作したのに対し、今回は **「何を検索するか（テスト発見の対象）」** を拡張する。これは受動的な記録追加でなく、能動的な repo search の範囲指定であり、探索行動そのものを増やす変更である（原則 #8 の条件「検証行動を直接誘発する」を満たす）。

---

## 改善仮説

**D2 のテスト検索範囲を、変更シンボルを直接参照するテストだけでなく、その oracle-bearing caller（テスト内でアサーションを持つ最近接の呼び出し元）まで拡張することで、relevant tests の取りこぼしを減らし、EQUIV / NOT_EQ 両方の正答率を改善できる。**

### 背景：なぜ直接参照だけでは不十分か

現行の D2 は `search for tests referencing the changed function, class, or variable` のみを指示している。しかしプロダクションコードでは、変更された関数が直接テストされていないケースが多い：

- 変更は内部ヘルパー関数（低レベル）に入っており、テストはその上位の公開 API を呼ぶ
- 変更は adapter / wrapper を通じてのみ呼ばれ、テストは adapter を通じて assertion する

このとき「直接参照テスト」を探しても見つからず、D2 の pass-to-pass テストの特定が不完全になる。

**oracle-bearing caller** = 変更シンボルを（直接または間接に）呼び出す関数のうち、それを対象とするテストがアサーションを持つ最近接のもの。この caller をテストするテストが、変更の影響を「観測」する最も有効なテストになる。

### 期待される効果

- **EQUIV 偽陽性の削減（主効果）**: 現状、エージェントは直接参照テストを探して「少数しか見つからず」「それらでは差異が出ない」と判断することがある。caller 経由のテストを発見すれば、変更の実際の影響を観測できるテストを追加で分析でき、EQUIV 判定の根拠がより完全になる。
- **NOT_EQ 偽陰性の削減（副効果）**: 同様に、caller テストが差異を検出できると、より確実な NOT_EQ 判定につながる。

---

## SKILL.md のどこをどう変えるか

### 変更対象

Compare モードの Certificate template 内の `D2` 定義、特に `To identify them:` の説明文。

### 変更前（現行）

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
    or variable. If direct test references are sparse, also search for callers,
    wrappers, or helpers of the changed symbol and find tests exercising those
    callers — prioritizing the nearest caller whose tests assert on observable
    outputs (return values, raised exceptions, or mutated state). If the test
    suite is not provided, state this as a constraint in P[N] and restrict the
    scope of D1 accordingly.
```

### 変更の内容

`To identify them:` の段落に 2 文（約 35 語）を挿入する。既存の文言は変更しない。

追加する 2 文の意図:
1. `If direct test references are sparse, also search for callers, wrappers, or helpers of the changed symbol and find tests exercising those callers` — 直接参照が少ない場合、caller/wrapper/helper のテストも探せという探索範囲の拡張
2. `prioritizing the nearest caller whose tests assert on observable outputs (return values, raised exceptions, or mutated state)` — 探索を効率化するため「最近接 oracle-bearing caller」を優先する優先順位指示

### 変更規模

- 追加: 2 文（約 35 語）
- 変更: 0（既存文言の削除・変更なし）
- 合計差分: 20行以内の目安を大幅に下回る

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV（現状 7/10）

**改善見込みあり。**

EQUIV 偽陽性の典型パターン:
1. エージェントが変更コードを trace し、コードパスに差異を見つける
2. 直接参照テストを探すが少数しかない
3. 見つかったテストでは差異が表面化しないと判断 → EQUIV と結論

この場合、caller 経由のテストを発見すれば、差異が observable outputs まで伝播するかどうかをより確実に検証できる。差異が伝播する場合は正しく NOT_EQ と判定でき、伝播しない場合は EQUIV を正しく確認できる。

予測: 7/10 → 8〜9/10（+1〜2件）

### NOT_EQ（現状 10/10）

**影響は中立〜正の方向。**

NOT_EQ では直接参照テストで既に差異が確認されているケースが多く、今回の変更は基本的に追加的な証拠を提供するだけ。
- caller テストで差異が確認できる追加証拠が増える（正方向）
- NOT_EQ の立証責任を非対称に引き上げる変更ではない（発火条件は「直接参照が sparse なとき」）

予測: 10/10 維持

### 一方向性についての評価

**変更は両方向に対称に作用する。**

- 追加するテストが差異を示す → NOT_EQ の証拠強化
- 追加するテストが差異を示さない → EQUIV の証拠強化

どちらの結論も、より完全なテストセットで検証されるため、精度が上がる。EQUIV 偽陽性の改善が主効果であるのは、現状のエラーパターン（EQUIV が 3/10 誤り）に合わせた予測であり、変更自体は対称に設計されている。

---

## failed-approaches.md ブラックリスト・共通原則との照合

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|---------------|
| BL-1 | ABSENT 定義追加 | 無関係（定義追加ではない） |
| BL-2 | NOT_EQ 証拠閾値強化 | 無関係（閾値変更ではない） |
| BL-3 | UNKNOWN 禁止 | 無関係 |
| BL-4 | 早期打ち切りゲート | 無関係（探索削減ではない、逆に拡張） |
| BL-5 | P3/P4 記録形式強化 | 異なる。前提テンプレートの記録形式変更ではなく、D2 の**検索スコープ指示** |
| BL-6 | Guardrail 4 対称化 | 無関係（Guardrail 変更ではない） |
| BL-7 | CHANGE CHARACTERIZATION | 無関係（分析前ラベル生成ではない） |
| BL-8 | Step 4 に Relevant to 列追加 | 異なる。受動的記録フィールドではなく、**能動的 repo search の範囲指定** |
| BL-9 | Trace check 自己チェック | 無関係（自己評価ではない） |
| BL-10 | Reachability ゲート | 無関係（条件分岐ゲートではない） |
| BL-11 | outcome mechanism 注釈追加 | 無関係（ANALYSIS ブロックへの注釈追加ではない） |
| BL-12 | テストソース先読み固定順序 | 異なる。探索順序の強制ではなく、**検索対象の拡張（"also search"）** |
| BL-13 | Key value データフロー欄 | 無関係（記録欄追加ではない） |
| BL-14 | Backward Trace チェックリスト追加 | 無関係（非対称な判定後の追加検証ではない） |
| BL-15 | COUNTEREXAMPLE の By P[N] 削除 | 無関係 |
| BL-16 | Comparison 直前への注釈追加 | 異なる。比較ステップの出力注釈ではなく、**テスト発見ステップの入力範囲拡張** |

### BL-8 との詳細比較

BL-8 の失敗本質:「受動的な記録フィールドの追加は能動的な検証を誘発しない」

本提案は **repo search という能動的な探索行動そのものを増やす** 指示であり、「何を書くか」のテンプレートではなく「何を検索するか」の行動指定。原則 #8 が明示する「検証行動を直接的に誘発する仕組みが必要」の条件を満たしている。

### BL-12 との詳細比較

BL-12 の失敗本質:「探索の開始順序を固定すると、最初に読んだ側へアンカリングが生じる」

本提案は探索の **順序** を固定しない。`also search` という言葉で「追加的に検索することもある」という拡張指示であり、既存の探索フローを変えない。`prioritizing the nearest caller` は読む順序の強制ではなく、複数の候補がある場合の優先度指示であり、探索コストを抑えるための合理的な絞り込みである。

### 共通原則との照合

| 原則 | 内容 | 照合結果 |
|------|------|---------|
| #1 判定の非対称操作 | EQUIV/NOT_EQ どちらかに有利な変更 | ✅ 非対称でない。追加テスト発見は両方向の証拠になりうる |
| #2 出力側の制約は効果なし | 「こう答えろ」という出力制約 | ✅ 出力制約ではない。探索行動（repo search）の対象を拡張する |
| #3 探索量削減は有害 | 探索を減らす変更 | ✅ 探索を増やす（`also search`）方向。削減ではない |
| #4 同じ方向の変更は同じ結果 | 表現が違っても効果の方向が同じなら失敗 | ✅ 過去 BL はテンプレート記録変更・判定閾値変更・順序固定であり、本提案の「検索対象拡張」とは方向が異なる |
| #5 入力テンプレートの過剰規定 | テンプレートで記録内容を限定する | ✅ 視野を広げる方向の変更（探索範囲の拡張）。過剰規定（視野の絞り込み）と逆方向 |
| #6 対称化は差分で評価せよ | 既存制約との差分の方向 | ✅ 変更前との差分は「callers/wrappers 経由のテスト検索の追加」のみ。EQUIV/NOT_EQ 両側に等しく作用する |
| #7 分析前ラベル生成はアンカリング | 中間ラベルが推論ショートカットになる | ✅ ラベル生成ではない |
| #8 受動的記録は検証を誘発しない | フィールド追加は検証行動にならない | ✅ 受動的記録ではなく、能動的 repo search を指示する |
| #9 メタ認知的自己チェック | 「やったか？」チェックは機能しない | ✅ 自己チェックではない |
| #10 必要条件ゲートの弁別力欠如 | ゲートが失敗モードを弁別しない | ✅ 条件分岐ゲートではない |
| #11 探索順序の固定 | 順序強制が偏りを生む | ✅ 順序は固定しない。`also search` による探索範囲拡張 |
| #12 アドバイザリ非対称指示 | 推奨形式でも判定の非対称化を招く | ✅ 非対称な指示ではない。`also search` は発火条件「sparse なとき」で両結論に等しく適用 |

---

## 変更規模

- 追加行数: 2 文（約 35 語）
- 変更行数: 0（既存文言の削除・変更なし）
- 合計差分: 20行以内の目安を大幅に下回る
