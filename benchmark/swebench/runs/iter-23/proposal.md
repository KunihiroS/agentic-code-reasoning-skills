# Iteration 23 — Proposal

## Exploration Framework カテゴリ: F（強制指定）

### カテゴリ F の選択理由

カテゴリ F は「原論文の未活用アイデアを導入する」であり、以下の3つのメカニズムを含む:

1. 論文に書かれているが SKILL.md に反映されていない手法を探す
2. 論文の他のタスクモード（localize, explain）の手法を compare に応用する
3. 論文のエラー分析セクションの知見を反映する

今回はメカニズム 2 と 3 を組み合わせて選択した。

**メカニズム 2（explain → compare 応用）の根拠:**
`explain` モードのテンプレート（論文 Appendix D）には `SEMANTIC PROPERTIES` セクションがある。
これは各関数・変数について「不変条件、制約、状態保証」を証拠付きで列挙する構造であり、
compare モードには直接対応するものがない。
compare の `EDGE CASES RELEVANT TO EXISTING TESTS` は入力境界条件の検討に留まっており、
「変更が変数・状態の意味的性質をどう変えるか」という観点が抜けている。

**メカニズム 3（エラー分析）の根拠:**
docs/design.md は論文 §4.1.1「subtle difference dismissal」を記録している。
これは「意味的な差異を発見しても、テスト結果に影響しないと誤判断する失敗」であり、
compare モードで EQUIVALENT を誤判定するケースの典型的原因である。
SEMANTIC PROPERTIES の手法でこの失敗パターンを直接抑制できる。

---

## 改善仮説

compare モードの EDGE CASES セクションに「入力境界条件だけでなく、
各変更が影響する意味的性質（不変条件・状態の制約・制御フロー上の前提）も
列挙対象として明示する」という指示を追加することで、
explain モードで有効な SEMANTIC PROPERTIES の視点を compare に導入し、
微細な意味的差異の見落とし（subtle difference dismissal）による
EQUIVALENT 誤判定を減らせる。

---

## SKILL.md の変更内容

### 変更箇所

compare テンプレート内の `EDGE CASES RELEVANT TO EXISTING TESTS` セクションの
見出し直下コメント行（現行）:

```
EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
```

この2行目を以下に精緻化する（1行の文言追加・既存行の精緻化）:

```
EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise — including not only
 input boundary conditions but also semantic invariants or state constraints
 that each change modifies, following the explain-mode SEMANTIC PROPERTIES approach)
```

### 変更の性質

- 既存行「(Only analyze edge cases that the ACTUAL tests exercise)」への文言追加・精緻化
- 新規ステップ・新規フィールド・新規セクションの追加ではない
- 説明的コメント行の内容を拡張するのみ

### 変更規模

追加・変更: 2行（元の1行を3行に展開）
削除: 1行（元の行を置き換え）
削除行を除いた変更行数 = 2行（hard limit 5行以内）

---

## 期待効果

### 対象失敗パターン

- **subtle difference dismissal（論文 §4.1.1）**: 2つの変更が意味的に異なる性質を持つにも
  かかわらず、「テスト結果には影響しない」と誤判断するケース。
  特に EQUIVALENT 誤判定（overall および equiv カテゴリ）で頻出する。

### 期待するメカニズム

EDGE CASES の分析対象に「意味的不変条件・状態制約」を明示することで、
エージェントは入力値の境界だけでなく、変更によって崩れる可能性のある
プログラム的性質（例: 処理順序の前提、状態の単調性、例外の有無）を
テストとの照合対象として意識しやすくなる。
これは explain モードの SEMANTIC PROPERTIES が「各関数の振る舞いを
不変条件として明文化する」ことで推論の抜け漏れを防ぐのと同じ原理である。

### 改善が期待されるカテゴリ

- overall: 全体正答率の底上げ（EQUIVALENT 誤判定の減少）
- equiv: EQUIVALENT 判定精度の向上（微細差異の検出率向上）
- not_eq: 直接的な改善効果は小さいが、意味的性質の検討が NOT_EQUIVALENT
  判定の根拠を補強する方向で間接的に作用しうる

---

## failed-approaches.md との照合

### 原則 1: 探索を特定シグナルの捜索に寄せすぎない

「意味的不変条件・状態制約」という概念は、「何を探すか」ではなく
「何の観点で考えるか」を拡張するものである。
特定のシグナル（例：特定の関数名、特定のパターン）を指定していないため、
確認バイアスを強める方向には作用しない。
→ 抵触なし

### 原則 2: 探索の自由度を削りすぎない

この変更は EDGE CASES セクションの分析対象を「より広く取る」方向への精緻化であり、
探索の自由度を削らず、むしろ考慮対象を拡張している。
→ 抵触なし

### 原則 3: 局所的な仮説更新を前提修正義務に直結させすぎない

EDGE CASES セクションは仮説更新ではなく、テストとの照合分析である。
仮説と前提の更新プロセス（Step 3）とは独立している。
→ 抵触なし

### 原則 4: 結論直前の自己監査に新しい必須判定ゲートを増やしすぎない

変更対象は ANALYSIS セクション内の EDGE CASES であり、
Step 5.5（Pre-conclusion self-check）ではない。
新しい判定ゲートを追加するものではない。
→ 抵触なし

---

## 変更規模の宣言

- 変更対象行: SKILL.md の compare テンプレート内 `EDGE CASES RELEVANT TO EXISTING TESTS:` 直下の1行
- 変更種別: 既存コメント行への文言追加・精緻化（展開）
- 追加・変更行数: 2行（hard limit 5行以内）
- 削除行数: 1行（制限カウント外）
- 新規ステップ・新規フィールド・新規セクション: なし
