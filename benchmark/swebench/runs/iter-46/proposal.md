# Iteration 46 — proposal.md

## カテゴリ: E (表現・フォーマットを改善する)

### カテゴリ内のメカニズム選択理由

カテゴリ E の三つのメカニズム（曖昧文言の具体化 / 簡潔化 / 例示）のうち、
今回は **曖昧文言の具体化** を選択する。

対象は Guardrail #5 の末尾文言。現行の「Confident-but-wrong answers often
come from thorough-but-incomplete analysis.」は、何が「不完全」なのかを
具体化していない。トレースの実施者は「downstream code を確認した」
だけで満足しやすい。upstream（値が生成・設定される箇所）も同様に
確認すべきであるという観点が隠れている。

この「upstream / downstream の両方を確認する」という二方向性は
コード推論の一般原則であり、特定言語・フレームワーク・ベンチマークに
依存しない汎用的な具体化である。

---

## 改善仮説

Guardrail #5 の末尾に「upstream と downstream の両方を検証する」という
方向性を明示することで、エッジケースを発見した後に片方向のトレースで
完了したとみなす誤りを減らし、全体的な推論チェーンの完全性が向上する。

---

## SKILL.md の変更内容

### 変更前

```
5. **Do not trust incomplete chains.** After building a reasoning chain,
   verify that downstream code does not already handle the edge case or
   condition you identified. Confident-but-wrong answers often come from
   thorough-but-incomplete analysis.
```

### 変更後

```
5. **Do not trust incomplete chains.** After building a reasoning chain,
   verify that downstream code does not already handle the edge case or
   condition you identified. Confident-but-wrong answers often come from
   thorough-but-incomplete analysis — verify both upstream (where the
   value was set or the state was created) and downstream (where it is
   consumed or checked).
```

### 変更の性質

- 既存行への文言追加（ダッシュ以降を末尾に付加）
- 削除行: 0
- 追加・変更行: 1 行（末尾文への追記）
- 変更規模宣言: **1 行**（hard limit 5 行以内、適合）

---

## 期待効果 — どのカテゴリ的失敗パターンが減るか

### 対象失敗パターン

**部分トレース完了による早期収束**:
関数 A がエッジケースを生成し、関数 B がそれを処理し、
関数 C で実際の影響が現れるケースにおいて、B（downstream）だけを
確認して「すでに処理されている」と結論する誤り、または
A（upstream）だけを確認して「この値が渡される」と結論する誤りが
減ることが期待される。

### overall への寄与

- `compare` モード: 二つの変更の振る舞い比較において、変更点から
  upstream/downstream の両方向にトレースすることで、片方だけが
  見逃していた副作用の検出精度が向上する。
- `diagnose` モード: 症状サイトと根本原因サイトの分離（Guardrail #3
  とも連携）において、upstream 方向への探索を促す表現が補強される。
- `explain` モード: Data flow analysis で変数の「生成 → 変更 → 使用」
  の三点追跡を既に求めているが、Guardrail 層でも同方向性が確認される
  ことで一貫性が増す。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|------|---------|
| 探索で探すべき証拠の種類をテンプレートで事前固定しすぎない | 問題なし。今回の変更は探索テンプレートへの追加ではなく、既存 Guardrail の文言精緻化。探索手順を固定しない。 |
| 探索の自由度を削りすぎない（読解順序の半固定など） | 問題なし。「upstream と downstream の両方を確認する」は方向性の示唆であり、読み始め順序や境界確定順序を固定しない。 |
| 局所的な仮説更新を前提修正義務に直結させすぎない | 問題なし。Guardrail #5 は前提管理ではなく、エッジケース発見後のトレース完全性に関するルールであり、前提の再点検を義務化しない。 |
| 結論直前の自己監査に新しい必須メタ判断を増やしすぎない | 問題なし。変更箇所は Step 5.5（Pre-conclusion self-check）ではなく Guardrail セクション。また文言追加は既存ガードレールの具体化であり、新たな判定ゲートを設けない。 |

全原則との照合: **抵触なし**

---

## 変更規模の宣言

- 変更行数: **1 行**（既存末尾文への文言追加）
- 削除行: 0
- 新規ステップ・新規フィールド・新規セクション: なし
- hard limit (5 行) に対する余裕: 4 行
