# Iter-47 Proposal

## Exploration Framework カテゴリ: F

カテゴリ F「原論文の未活用アイデアを導入する」の中でも、
「他のタスクモード (explain) の手法を compare に応用する」メカニズムを選択する。

### メカニズム選択理由

explain モードのテンプレートには DATA FLOW ANALYSIS セクションがある。
このセクションは変数・値の「生成 → 変更 → 使用」という状態遷移を追跡し、
それが観測可能な出力に反映されるかを確認する。

compare モードのテンプレートには、テスト呼び出しフローのトレース (Claim C[N].1/C[N].2) は
あるが、変更された式・値・オブジェクト状態が最終的に同一観測値を生むかを明示する
観点が欠けている。論文の Patch Equivalence Verification テンプレート (Appendix A) が
「per-test iteration と formal definition」を軸にするのに対し、explain の
「state-tracing」アプローチを per-claim 粒度で持ち込むことは、論文自体が
"templates act as certificates" と述べた趣旨に沿う未活用の拡張である。

---

## 改善仮説 (1 つ)

compare モードで EQUIVALENT を誤判定するケースの一因は、
各クレームが「コード変更 → テスト結果」の呼び出し経路だけを追い、
途中の変数・返値の「観測等価性」を明示しないことにある。
explain モードの DATA FLOW ANALYSIS から着想を得て、
各クレームの因果記述に「どの値/状態が両変更で同一になるか」を
一文で宣言させる精緻化を加えれば、
implicit な等価前提を explicit にし、見落とされがちな微細差分を
意識的にチェックするよう推論を誘導できる。

---

## SKILL.md の変更内容

### 変更箇所

compare テンプレートの ANALYSIS OF TEST BEHAVIOR セクション内、
Claim C[N].1 と C[N].2 の記述フォーマットを精緻化する。

### 変更前 (現行)

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line]
```

### 変更後 (提案)

```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line];
                the observed value/state at the assertion is [value or expression]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace from changed code to test assertion outcome — cite file:line];
                the observed value/state at the assertion is [value or expression]
```

### 変更規模宣言

変更行数: 2 行 (既存 2 行への文言追加。新規ステップ・フィールド・セクションは追加しない)
削除行: 0 行
合計変更規模: 2 行 ≤ hard limit (5 行)

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. 「subtle difference dismissal」(Guardrail #4 / docs/design.md §4.1.1 参照)
   - 現行: クレームがフロー経路のみを記述するため、論理的には差分があっても
     値レベルで同一になる場合に "probably same" と流してしまいやすい。
   - 変更後: アサーション地点での観測値/状態を明示する義務が生じるため、
     「経路が違っても値は同じ」または「経路の違いが値の違いに波及する」を
     それぞれ明確化せざるを得ない。

2. 「incomplete reasoning chains」(§4.3 Error Analysis)
   - 中間変数の変換が観測値に繋がるかを宣言させることで、
     call chain の途中で追跡が暗黙的に打ち切られる問題を抑制する。

### EQUIVALENT / NOT_EQUIVALENT カテゴリへの影響

- EQUIVALENT 誤判定: 値の等価宣言を強制することで、
  「両変更が同じ観測値を生む」ことの論拠が明示化され、
  根拠なき EQUIVALENT 判定が減少すると期待。
- NOT_EQUIVALENT 正判定: 差分が観測値に波及するかの宣言が
  COUNTEREXAMPLE セクションの記述精度を向上させる。
- overall: 両方向に対してクレームの粒度が上がるため、全体スコアの底上げが見込める。

---

## failed-approaches.md 汎用原則との照合

| 原則 | 照合結果 |
|------|----------|
| 探索を「特定シグナルの捜索」へ寄せすぎない | 非抵触: 変更はどの値/状態を見るかを限定しない。アサーション地点での観測値を「宣言する形式」を追加するだけであり、探索経路の固定ではない。 |
| 探索の自由度を削りすぎない | 非抵触: 既存の Claim フォーマットへの一文追記であり、「どこを読むか」「どの順序で進むか」を変えない。 |
| 局所的な仮説更新を前提修正義務に直結させない | 非抵触: 前提 (PREMISES セクション) や仮説更新 (Step 3) には一切触れない。 |
| 既存ガードレールを特定方向で具体化しすぎない | 非抵触: Guardrail #4 (subtle difference dismissal) の強化ではなく、explain モードの data flow 観点を compare の Claim 記述に移植するカテゴリ F の適用であり、ガードレール本文を変更しない。 |
| 結論直前の自己監査に新しい必須メタ判断を増やさない | 非抵触: 変更箇所は ANALYSIS セクション内の Claim 記述のみ。Step 5.5 Pre-conclusion self-check には触れない。 |

全原則について抵触なしと判断する。

---

## 研究コア構造の維持確認

- 番号付き前提 (PREMISES): 変更なし
- 仮説駆動探索 (Step 3): 変更なし
- 手続き間トレース (Step 4 / interprocedural trace table): 変更なし
- 必須反証 (Step 5 / COUNTEREXAMPLE CHECK): 変更なし

コア構造はすべて維持される。
