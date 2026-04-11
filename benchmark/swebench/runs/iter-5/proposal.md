# Iter-5 — Proposal

## Exploration Framework カテゴリ: F

### カテゴリ内での具体的なメカニズム選択理由

カテゴリ F は「原論文の未活用アイデアを導入する」であり、以下の3サブタイプを持つ:

1. 論文に書かれているが SKILL.md に反映されていない手法
2. localize / explain モードの手法を compare に応用する
3. 論文のエラー分析知見を反映する

今回は **サブタイプ 2** を選択する。

論文の Fault Localization テンプレート (Appendix B) の Phase 2 は、メソッドごとに
`| RELEVANT |` 列を持ち、「このメソッドが前提 T[N] に対してなぜ重要か」を
強制的に記述させる構造になっている。

現行 SKILL.md の `compare` モードが使う Step 4 (Interprocedural tracing) の
テーブルヘッダーはこの RELEVANT 列を持たない:

```
| Function/Method | File:Line | Behavior (VERIFIED) |
```

EQUIVALENT ペアで誤判定が起きる主因のひとつは、トレース済みの関数が
「実際にテスト結論に到達する経路上にあるか」を明示的に確認しないまま
EQUIVALENT / NOT EQUIVALENT を宣言してしまうことである。
これは docs/design.md が指摘する「不完全な推論チェーン」失敗パターンと合致する。

localize モードの per-method RELEVANT 列を compare モードの Step 4 に
持ち込むことで、エージェントが各関数トレースの段階で
「このトレースは relevant test の判定に接続しているか」を自問できる。

---

## 改善仮説

interprocedural tracing テーブルに「このメソッドがどのテストの判定に
どのような理由で関連するか」を明示する列を追加することで、
不完全なトレースによる EQUIVALENT 誤判定 (confident-but-wrong) の頻度が
減少し、compare モードの overall 正答率が向上する。

---

## SKILL.md への具体的な変更内容

### 対象箇所

Step 4 (Interprocedural tracing) のテーブルヘッダーおよびサンプル行。

### 変更前 (既存の2行)

```
| Function/Method | File:Line | Behavior (VERIFIED) |
|-----------------|-----------|---------------------|
| [name] | [file:N] | [actual behavior after reading the definition] |
```

### 変更後 (2行の列追加、変更規模 = 2行)

```
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| [name] | [file:N] | [actual behavior after reading the definition] | [which test(s) and why this function is on the relevant path] |
```

### 変更規模宣言

変更行数: **2行** (ヘッダー行 + サンプル行の列追加のみ)
削除行: 0行
制限(5行)以内: YES

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **不完全な推論チェーン (Incomplete reasoning chains)**
   docs/design.md §4.3 Error Analysis に記載。エージェントが複数の関数を
   トレースしながら「それが本当にテスト判定に繋がっているか」の確認を
   省略してしまうパターン。Relevance 列への記入が確認を強制する。

2. **微細な差異の棄却 (Subtle difference dismissal)**
   Guardrail #4 の対象パターン。変更後の挙動差を見つけたが
   「テストには影響しないだろう」と結論づけるケース。
   Relevance 列でトレース経路を明示することで、
   その差異が実際に relevant test の経路上にあるかを
   テーブル記入時点で問い直せる。

3. **EQUIVALENT 誤判定 (compare モード)**
   README.md が報告する「2つの持続的失敗はどちらも EQUIVALENT ペア」
   に対応。トレースの接続性確認が不十分なまま EQUIVALENT を宣言する
   誤判定を減らすことが期待される。

---

## failed-approaches.md との照合結果

現時点の failed-approaches.md に記載されている汎用原則: **なし**
(ベンチマーク刷新に伴いリセット済み)

抵触する制約: **なし**

---

## 変更規模の宣言

- 追加・変更行: 2行
- 削除行: 0行
- Hard limit (5行): 充足
- 新規ステップ・新規フィールド・新規セクション: なし
  (既存テーブルの列数変更のみ)
