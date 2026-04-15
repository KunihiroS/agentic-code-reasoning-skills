# Iter-60 Proposal

## Exploration Framework カテゴリ: A（強制指定）

カテゴリ A「推論の順序・構造を変える」の中から、今回は
**逆方向推論（結論から逆算して必要な証拠を特定する）** を選択する。

### カテゴリ A 内での具体的なメカニズム選択理由

現行の SKILL.md は compare モードで「STRUCTURAL TRIAGE → PREMISES → ANALYSIS」
という前方向の手順を踏む。この順序では、詳細トレースを開始した後に初めて
「この証拠探索は本当に結論の判定に寄与するか」が問われる。その結果、広く
証拠を集めつつも、最終的な EQUIVALENT / NOT_EQUIVALENT 判定に直結する
境界条件の確認が後回しになりやすい。

逆方向推論を部分的に導入し、トレース開始前に
「EQUIVALENT と結論するには何が真でなければならないか」
「NOT_EQUIVALENT と結論するには何が真でなければならないか」
を箇条書きで宣言させることで、探索の照準を絞ることができる。
これは推論の実行順序を変える（順方向→逆方向のハイブリッド）介入であり、
カテゴリ A の「逆方向推論」に該当する。

---

## 改善仮説（1つ）

STRUCTURAL TRIAGE と PREMISES の間に「DECISION CONDITIONS」宣言を置き、
「いずれの結論を出すために何が成立する必要があるか」を先行宣言させることで、
その後の ANALYSIS で証拠収集の優先順位が自然に結論条件と整合し、
判定に直結しない周辺トレースへの迷走が減る。

---

## SKILL.md の変更内容

### 変更箇所

compare モードの Certificate template 内、PREMISES セクションの直後（P4 の後）に
1 行の宣言フィールドを追加する。

### 変更前（該当行、SKILL.md line 201–203）

```
P3: The fail-to-pass tests check [specific behavior]
P4: The pass-to-pass tests check [specific behavior, if relevant]

ANALYSIS OF TEST BEHAVIOR:
```

### 変更後

```
P3: The fail-to-pass tests check [specific behavior]
P4: The pass-to-pass tests check [specific behavior, if relevant]
DECISION CONDITIONS: EQUIVALENT requires [what must hold]; NOT_EQUIVALENT requires [what must hold]

ANALYSIS OF TEST BEHAVIOR:
```

### 変更規模の宣言

追加: 1 行（hard limit 5 行以内に収まる）
削除: 0 行
合計変更行数: 1 行

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **トレース迷走による判定ブレ（overall）**
   詳細なトレースを行った末に、その証拠が結論条件と対応しているか曖昧な
   まま EQUIVALENT / NOT_EQUIVALENT を宣言するケースが減る。
   DECISION CONDITIONS を事前宣言しておくことで、ANALYSIS 中に収集する証拠が
   「何を確定させれば判定できるか」という照準を持つ。

2. **判定に関与しないパスへの過剰トレース（overall）**
   逆算された「この結論に必要な条件」が明示されていることで、関係のない
   コードパスへの深掘りを自然に抑制する。

3. **証拠と結論の接続の弱さ（overall）**
   FORMAL CONCLUSION で「By P1 and C2…」と書く際、DECISION CONDITIONS との
   照合を意識するため、結論が証拠に正しく根拠づけられているかの
   自己確認が促進される。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 抵触有無 | 理由 |
|------|----------|------|
| 探索シグナルを事前固定しすぎない | 抵触なし | DECISION CONDITIONS は「何の証拠を探すか」ではなく「どの命題が成立すれば結論が出るか」を宣言するもので、探索経路は固定しない |
| 探索の自由度を削りすぎない（読解順序の半固定含む） | 抵触なし | 追加するのは PREMISES の末尾への 1 行宣言のみ。どのファイルを読むか、どの順序で読むかは引き続き H[N] 仮説に委ねる |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 抵触なし | DECISION CONDITIONS は初期宣言であり、探索中の仮説更新とは独立している。更新義務は課さない |
| 既存ガードレールを特定方向で具体化しすぎない | 抵触なし | Guardrail #4（差異を無視しない）や #2（トレースなしの判定禁止）を上書き・具体化するものではなく、判定のための条件整理という別レイヤーの介入 |
| 結論直前の自己監査に必須のメタ判断を増やしすぎない | 抵触なし | 変更は PREMISES 後の宣言フィールド追加であり、Step 5.5（Pre-conclusion self-check）には手を加えない |

以上、いずれの失敗原則にも抵触しない。

---

## 変更規模の宣言（再掲）

- 追加行数: 1 行
- 削除行数: 0 行
- 変更対象: compare モード Certificate template 内の PREMISES ブロック末尾
- Hard limit（5 行以内）: 満たしている
