# Iteration 41 — Proposal

## Exploration Framework カテゴリ: F

カテゴリ F「原論文の未活用アイデアを導入する」を選択した。

### カテゴリ内での具体的なメカニズム選択理由

Objective.md の F の定義には三つのメカニズムが列挙されている:

1. 論文に書かれているが SKILL.md に反映されていない手法を探す
2. 論文の他のタスクモード (localize, explain) の手法を compare に応用する
3. 論文のエラー分析セクションの知見を反映する

今回は **メカニズム 2** を採用する。

`explain` モードの certificate template には **DATA FLOW ANALYSIS** セクションが存在する。
これは「変数がどこで生成され、どこで変更され、どこで使用されるか」を明示的に追跡させる
技法であり、論文 Appendix D で定義されたものだ。

`compare` モードの ANALYSIS OF TEST BEHAVIOR では、各 Claim において
「変更されたコードからテストのアサーション結果までのトレース」を求めているが、
現状の指示は **変更点そのものの記述** に留まりがちで、
**変更された値がどの変数経路を経てアサーションに到達するか** の追跡を
明示的に促していない。

explain のデータフロー追跡の概念（生成→変更→使用の連鎖）を compare の
Claim トレース指示に 1 行の精緻化として加えることで、
等値判定に直結するデータ伝播経路を明確化できる。

---

## 改善仮説

**仮説**: compare モードの Claim トレース指示に「変更された値がアサーション到達まで
どの変数・戻り値を経由するか」を追うよう 1 行精緻化することで、
変更箇所と最終アサーションの間に存在する伝播経路の見落とし（EQUIVALENT 誤判定）
を減らし、全体的な推論品質が向上する。

この仮説は explain モードの DATA FLOW ANALYSIS（論文 Appendix D）のコアである
「変数の生成・変更・使用を連鎖的に記録する」という観点を、
compare の証拠収集フェーズに適用するものである。

---

## SKILL.md の変更内容

### 変更箇所

SKILL.md の compare 証明書テンプレート内、ANALYSIS OF TEST BEHAVIOR の
Claim の説明行 (現行 208-209 行付近):

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
```

### 変更後

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line;
                follow the changed value through each variable or return it flows into before reaching the assertion]
```

同様に Claim C[N].2 の行も同一の精緻化を適用する:

```
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line;
                follow the changed value through each variable or return it flows into before reaching the assertion]
```

### 変更の性質

- 既存行への文言追加（精緻化）のみ
- 新規ステップ・新規フィールド・新規セクションなし
- 変更行数: 2 行（C[N].1 の 1 行 + C[N].2 の 1 行）

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

**「不完全な推論チェーン」（docs/design.md §4.3 Error Analysis）**:

エージェントが変更箇所から直接アサーションへ飛んで中間の変数伝播を省略する
ケースが改善される。現行の指示「trace from changed code to test assertion outcome」は
経路の存在は求めているが、その経路を変数単位で追うことを明示していない。
「changed value が流れる各変数・戻り値を辿る」という一文を加えることで、
データ伝播の中間ステップを明示的に記録させ、見落としを防ぐ。

**overall 向上の期待メカニズム**:

- EQUIVALENT 誤判定: 変更された値の伝播先を追うことで、
  「この違いはアサーションに届かないから無視できる」という誤推論を防ぐ
- NOT_EQUIVALENT 誤判定: 伝播経路を辿ることで「実は別パスで同じ値になる」
  という事実を見落とさなくなる
- 両方向に対して推論の粒度が上がることで全体正答率が向上する

---

## failed-approaches.md の汎用原則との照合

| 原則 | 抵触の有無 | 根拠 |
|------|-----------|------|
| 探索シグナルを事前固定しすぎる変更は避ける | 抵触なし | 「変数経路を辿る」は探索の型を固定するのではなく、既存 Claim 記述内の追跡粒度を高める精緻化であり、何を読むかを指定していない |
| 読解順序を半固定して探索の自由度を削らない | 抵触なし | 変更は Claim の記述指示に留まり、どのファイルをどの順で読むかには影響しない |
| 局所的な仮説更新を前提修正義務に直結させない | 抵触なし | 仮説更新プロセス (Step 3) には触れていない |
| 結論前の必須メタ判断を増やしすぎない | 抵触なし | Step 5.5 (Pre-conclusion self-check) への変更ではなく、ANALYSIS フェーズの Claim 記述指示への精緻化 |

全原則と非抵触。

---

## 変更規模の宣言

- 追加・変更行数: **2 行**（5 行以内の hard limit を満たす）
- 削除行数: 0 行
- 変更の種類: 既存行への文言追加（精緻化）のみ。新規ステップ・フィールド・セクションなし
