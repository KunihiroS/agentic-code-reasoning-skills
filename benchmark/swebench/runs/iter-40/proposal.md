# Iter-40 — Proposal

## Exploration Framework カテゴリ

カテゴリ: **E. 表現・フォーマットを改善する**

### カテゴリ E 内でのメカニズム選択理由

カテゴリ E の 3 つのメカニズム（曖昧文言の具体化 / 簡潔化 / 例示）のうち、
「曖昧文言の具体化」を選択する。

理由: compare モードの `NO COUNTEREXAMPLE EXISTS` ブロックにある
`Searched for:` フィールドは、モデルが「何を探したか」を書く欄だが、
どの粒度・どの種類のシグナルを探せばよいかが明示されていない。
その結果、モデルは "any behavioral difference" のような抽象的な記述で
形式的に充填しがちであり、実際のアサーション文字列やコード条件への
着目が促されない。対照的に `Found:` フィールドにはすでに括弧注記
"cite file:line, or NONE FOUND with search details" があり、
`Searched for:` 側との対称性が崩れている。

この非対称を解消し、Guardrail #4（subtle differences を dismiss しない）
が求める「differing code path を少なくとも 1 つのテストでトレース」という
行動を、テンプレート記入段階から誘導するのが今回の改善対象である。


## 改善仮説

`Searched for:` フィールドに「アサーション条件またはコード条件」という
具体的な探索粒度を示すことで、モデルが実際のアサーション内容を
確認してから EQUIVALENT を宣言する割合が増加し、
subtle difference を見逃す誤判定（overall および equiv カテゴリの
偽陽性 EQUIVALENT）が減少する。


## 変更内容

### 変更箇所

SKILL.md の compare モード Certificate template 内の
`NO COUNTEREXAMPLE EXISTS` ブロック、`Searched for:` 行。

### 変更前

```
    Searched for: [specific pattern — test name, code path, or input type]
```

### 変更後

```
    Searched for: [specific pattern — assertion text or condition, test name, code path, or input type]
```

### 変更の意図

括弧内の列挙リストの先頭に "assertion text or condition," を追加する。
これにより、モデルは「どのアサーション文言・条件式を探したか」を
`Searched for:` に記述することが自然な行動として促される。

`Found:` 側の "cite file:line" という既存指示と対になり、
「探した観点（assertion text）→ 見つかった場所（file:line）」
という一貫した探索ログとして機能する。


## 期待効果

### 減少が期待される失敗パターン

1. **形式的充填による subtle difference スルー**
   モデルが "no behavioral difference found" と抽象的に記述して
   実際のアサーション内容を確認しないまま EQUIVALENT と宣言する
   パターンを抑制する。
   → Guardrail #4（"Do not dismiss subtle differences"）の
     テンプレートレベルでの強化に相当。

2. **`Searched for:` と `Found:` の粒度ミスマッチ**
   `Searched for:` が「広い概念」で `Found:` が「具体的な file:line」
   になるという構造的な矛盾が、推論ログとしての一貫性を損なっていた。
   具体化により両フィールドの粒度が揃い、自己チェック時に
   不整合が可視化されやすくなる。

3. **overall および equiv での偽陽性 EQUIVALENT**
   アサーション条件の相違が実際には存在するのに、
   「コードパス上の差異」としか記述されずに見逃される
   ケース（overall の損失パターン）を削減できる。


## failed-approaches.md との照合

| 汎用原則 | 抵触するか |
|----------|-----------|
| 探索を「特定シグナルの捜索」に固定しすぎない | **抵触しない** — 今回の変更はシグナルの種類を追加列挙しているが、削除・置換ではない。既存の "test name, code path, or input type" はそのまま残るため、探索の自由度は維持される。 |
| 探索順序を半固定しない | **抵触しない** — `Searched for:` はすでに存在するフィールドであり、順序変更は行っていない。 |
| 局所的な仮説更新を前提修正義務に直結させすぎない | **抵触しない** — 前提（Premises）セクションではなく、counterexample check の記述粒度を変えるだけ。 |
| 結論前の自己監査に新しい必須判断を増やしすぎない | **抵触しない** — 新しいステップ・フィールド・セクションは追加していない。既存 `Searched for:` の括弧内文言の精緻化のみ。 |


## 変更規模の宣言

- 変更行数: **1行**（既存行への文言追加）
- 削除行数: 0行
- 合計 diff 行数: 1行（hard limit 5行以内に適合）
- 新規ステップ・新規フィールド・新規セクション: **なし**
