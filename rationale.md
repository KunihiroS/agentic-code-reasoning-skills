# Iteration 36 — Rationale

## 対象問題

EQUIV 偽陰性（false negatives for EQUIV）：エージェントがコードレベルの差異を発見し、テスト結果が実際に異なるかを検証せずに即 NOT_EQ と結論するショートカット。

## 前回（Iter-35）の提案と失敗理由

Iter-35 では Compare テンプレートの ANALYSIS 前に `CONTRACT DELTA` として各変更シンボルの `return / raises / mutates / emits / Delta / Test focus` を記録する 7 行を追加しようとした。

**審査結果（FAIL / 12/21）の核心：**
- `Delta` と `Test focus` を ANALYSIS の**前に**書かせる構造が、後続の分析を「先に書いた要約の追認」に変える（BL-7: 分析前の中間ラベル生成はアンカリングバイアスを導入する）
- `return / raises / mutates / emits` という固定枠が新たな受動的記録フィールドであり、能動的検証を誘発しない（BL-8, BL-13, BL-16）
- 高粒度テンプレートにより認知負荷が増大し、ターン消費が増える（BL-5 懸念）

## 今回（Iter-36）の変更

### 変更内容

`ANALYSIS OF TEST BEHAVIOR` の `Claim C[N].1 / C[N].2` のトレース要件を変更：

**変更前：**
```
Claim C[N].1: With Change A, this test will [PASS/FAIL]
              because [trace through code — cite file:line]
```

**変更後：**
```
Claim C[N].1: With Change A, this test will [PASS/FAIL]
              because [trace through changed code to the assertion or exception — cite file:line]
```

同様に `COUNTEREXAMPLE` の `because [reason]` も `because [trace from changed code to the assertion or exception — cite file:line]` に変更。

### 変更の意図

- トレースの終端を「コードの振る舞い」から「テストのアサーションまたは例外」に明示する
- コード差異を発見しただけで止まるのではなく、その差異がテスト結果レベルまで伝播するかを明示的に追わせる
- 「コード差分のみで DIFFERENT」というショートカットを、テンプレート構造のレベルで防ぐ

### 既知の失敗パターンとの整合性確認

| 原則 | 適合するか |
|------|-----------|
| BL-7（分析前の中間ラベル生成） | ✅ 変更は ANALYSIS 内部の既存フィールドを修正するのみ、事前ラベル生成なし |
| BL-8（受動的記録フィールド） | ✅ 新フィールド追加なし、既存 Claim の記述要件を具体化するだけ |
| BL-2（NOT_EQ 証拠閾値の引き上げ） | △ トレース終端の明示化は追加的な精緻さを要求するが、「assertion または exception への到達」は本来のトレース義務の自然な終端であり、新しい立証責任ではない。また COUNTEREXAMPLE の `[reason]` → 同等のトレース要件への統一は、既存の Claim との整合性確保であり一方的な閾値引き上げではない |
| BL-5（複雑性・認知負荷） | ✅ 既存行の語句修正のみ（各行 6〜8 単語の差分）。新セクション追加なし |
| BL-16（Comparison 直前の観測フレーミング） | ✅ `Comparison:` 行を変更しない。Claim 行のみを修正 |
| 原則 #1（判定の非対称操作） | ✅ Change A と Change B の両方に同一の変更を適用。対称 |

### 想定効果と限界

**想定効果：**
- エージェントが `Claim C[N].1: FAIL because [return value differs]` という形でコード差分を理由に記録するだけで済ませる慣行を防ぐ
- `to the assertion or exception` という終端明示により、assertion に到達しない差異（内部状態の差異で外側に漏れない場合）を NOT_EQ の根拠として採用しにくくなる

**限界・リスク：**
- コード差分が assertion まで到達するケース（真の NOT_EQ）でも、「アサーションまで追う義務」が探索ターン数を僅かに増やす可能性がある
- 効果は Change Claim の記述要件の精緻化であり、根本的な推論能力の向上ではない。探索不足起因の EQUIV 偽陽性は別途対策が必要

## 対象ケース

Iter-35 rationale で挙げられた EQUIV 偽陰性ケース群（`django__django-15368` 等）。これらでは変更コードの意味論的差異は存在するが、テストのアサーションが到達する経路では差異が消滅するため、コードレベルのトレースだけで NOT_EQ と誤判定していた可能性がある。
