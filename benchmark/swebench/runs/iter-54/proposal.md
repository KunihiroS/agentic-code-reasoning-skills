# Iteration 54 — Proposal

## Exploration Framework カテゴリ

カテゴリ: A — 推論の順序・構造を変える

### カテゴリ内での具体的なメカニズム選択理由

カテゴリ A には「逆方向推論 (backward reasoning)」がある。
現在の `compare` テンプレートの PREMISES セクションは「変更 A/B が何をしているか」を順方向に
列挙するだけで終わっている。これは証拠収集の前提を揃えるが、「どの差異が判定を左右するか」
という問いを立てる前にトレースへ進ませてしまう。

逆方向推論を PREMISES の末尾に 1 行として埋め込むことで、エージェントはトレース開始前に
「もし NOT EQUIVALENT であれば、どこで分岐するか」を明示的に予測する。
この予測は探索経路そのものを変えず (探索の自由度は保持)、証拠の読み方の「向き」を
変えるだけである。予測と実際のトレース結果を突き合わせることで、
「差異を見落としたままトレースを終える」という失敗パターンが早期に検出できる。

カテゴリ B (情報取得方法) や E (表現改善) ではなくカテゴリ A を選んだのは、
変更が「何を読むか」ではなく「どの順序で問いを立てるか」に作用するためである。


## 改善仮説

比較判定に先立って「判定を左右しうる最小の意味的差異」を PREMISES 段階で
逆方向に予測させると、エージェントはその予測を反証または確認するためにトレースを行うため、
差異の見落とし (subtle difference dismissal) と EQUIVALENT への早期収束が減少し、
overall 正答率が向上する。


## SKILL.md への具体的な変更

### 変更対象

`compare` テンプレート内の PREMISES セクション末尾 (P4 の直後、ANALYSIS の直前)

### 変更前 (該当行)

```
P4: The pass-to-pass tests check [specific behavior, if relevant]
```

### 変更後

```
P4: The pass-to-pass tests check [specific behavior, if relevant]
P_inv: If the changes are NOT EQUIVALENT, the minimum divergence is predicted at:
       [name the narrowest code location or behavioral difference that would cause
        a test outcome to differ — derive from P1–P4 before reading any file]
```

### 変更の意図

- P_inv は「逆方向前提 (inverse premise)」として機能する。
- PREMISES フェーズを先に閉じてからトレースへ進む既存の直列構造は維持する。
- P_inv は P1–P4 を根拠に導出するため、根拠のない推測ではなく証拠連鎖の一部となる。
- トレース後に P_inv が REFUTED された場合はその事実を COUNTEREXAMPLE CHECK で
  明示する。CONFIRMED された場合は COUNTEREXAMPLE の具体的な根拠として引用できる。
- 追加は 2 行 (P_inv 宣言行 + 内容記述行) であり、5 行以内の制約を満たす。


## 期待される一般的な推論品質への効果

### 減少が期待される失敗パターン

1. **subtle difference dismissal** (Guardrail #4 が対象とする失敗類型)
   - 現状: 差異を発見しても「テスト結果に影響しない」と即断する。
   - 改善後: P_inv で「この差異がテスト分岐を生む」と先に予測しているため、
     発見した差異を P_inv と照合せずに棄却しにくくなる。

2. **EQUIVALENT への早期収束**
   - 現状: 表面的な等価性を確認した時点でトレースを打ち切る傾向がある。
   - 改善後: P_inv が「もし違うとしたらここだ」と具体的な場所を指しているため、
     その場所を検証するまでトレースを継続する動機づけとなる。

### overall ドメインへの適用

P_inv は PREMISES 内の 1 前提として機能し、全テストのトレース共通の参照点となる。
equiv / not_eq どちらの方向にも効く (equiv では P_inv が REFUTED されたことの
証拠として使い、not_eq では P_inv が CONFIRMED される形で結論を支える)。


## failed-approaches.md の汎用原則との照合

| 原則 | 本提案との関係 |
|------|---------------|
| 探索を「特定シグナルの捜索」へ寄せすぎない | P_inv は「読む順序」や「どのファイルを読むか」を制約しない。探索経路の自由度は変えていない |
| 探索ドリフト対策で読解順序を半固定しない | 変更は PREMISES 内の思考の向きであり、ファイルを読む順序には触れない |
| 局所的な仮説更新を即座の前提修正義務に直結させない | P_inv は探索中の更新義務ではなく、トレース開始前の 1 回の予測である。仮説更新ループとは独立 |
| 既存ガードレールを特定の追跡方向で具体化しすぎない | P_inv は Guardrail #4 を特定方向に絞るのではなく、判定直前ではなく判定前提として逆方向の問いを前置するだけ |
| 結論直前の自己監査に新しい必須のメタ判断を増やさない | 変更は Step 2 (PREMISES) への追記であり、Step 5.5 (Pre-conclusion self-check) や Step 6 には触れない |

全 5 原則との抵触なし。


## 変更規模の宣言

追加行数: 2 行 (P_inv 宣言行と内容記述行)
削除行数: 0 行
合計変更行数 (追加のみカウント): 2 行

hard limit 5 行以内を満たしている。
