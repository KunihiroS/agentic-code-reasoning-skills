# Iteration 35 — Proposal

## Exploration Framework カテゴリ: F (強制指定)

カテゴリ F「原論文の未活用アイデアを導入する」の中で、今回選択した
メカニズムは「localize モード (Appendix B) の divergence claim 構文を
compare モードに応用する」である。

### メカニズム選択理由

docs/design.md によれば、論文 Appendix B (Fault Localization) の
PHASE 3 "DIVERGENCE ANALYSIS" では、コード上の振る舞いが前提
(PREMISE T[N]) とどこで乖離するかを `CLAIM D[N]` 形式で明示させる。
この「乖離クレーム＋前提番号の対応」構文は現行 SKILL.md の compare
テンプレートには移植されておらず、DIFFERENT 判定の際に「なぜ異なるか」
を前提に紐づける強制的な根拠づけが欠けている。

一方 explain モードには SEMANTIC PROPERTIES という「性質ごとに
file:line 証拠を要求する」構造が既にある。これは Appendix D の移植結果
だが、compare でも「差分が生じた箇所と前提の対応を性質クレームとして
宣言させる」同等の強制機構が有益である。

よって今回は Appendix B の divergence claim パターンを compare の
ANALYSIS ブロックに一行追加する形で応用する。

---

## 改善仮説

compare モードで DIFFERENT 判定を下す際、エージェントが「差分が
存在すること」を指摘するに留まり、「その差分がどの前提に照らして
テスト結果を変えるか」を明示しない場合、根拠の薄い NOT EQUIVALENT
判定が発生しやすい。逆に EQUIVALENT と誤判定する際も、前提への
紐づけが曖昧なために差分の実効的影響が見落とされる。

DIFFERENT 結論が生じる都度、乖離クレームとして「file:line, Change A
vs B の振る舞いの違い, および矛盾する前提番号」を宣言させることで、
根拠なき DIFFERENT 断言と、前提照合をすり抜ける EQUIVALENT 誤判定の
両方を抑制できる。

---

## SKILL.md への具体的な変更内容

変更対象: compare テンプレートの ANALYSIS OF TEST BEHAVIOR ブロック内、
各テスト分析の末尾行。

### 変更前 (SKILL.md 行 213)

```
  Comparison: SAME / DIFFERENT outcome
```

### 変更後

```
  Comparison: SAME / DIFFERENT outcome
  If DIFFERENT — Divergence claim: at [file:line], Change A produces [X], Change B produces [Y], contradicting P[N]
```

変更規模: 追加 1 行、削除 0 行。合計変更 1 行。

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. NOT EQUIVALENT の根拠不足 (overall / not_eq 方向)
   - 差分の検出とその前提照合が分離している現状では、エージェントが
     「意味の違い」を見つけた後に前提との対応づけを省略しやすい。
   - Divergence claim の宣言を挟むことで、前提 P[N] に紐づかない
     DIFFERENT 断言が自己矛盾として可視化される。

2. EQUIVALENT の誤断定 (overall / equiv 方向)
   - 強制的な乖離クレームを書こうとした際に該当する前提が存在しない
     ことが判明すると、エージェントは差分が実際には前提に影響しない
     ことを能動的に確認する動線に乗る。これにより Guardrail #4
     (「微妙な差異を無視しない」) の遵守が強化される。

3. Guardrail #4 の運用精度向上 (compare 全般)
   - 現行 SKILL.md は Step 5.5 のチェックリストで Guardrail #4 を
     参照しているが、それは結論直前の自己チェックである。
   - 提案変更はテスト分析の本文中に乖離根拠を残す義務を埋め込むため、
     自己チェック依存でなく構造的に担保できる。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 本提案との関係 |
|------|---------------|
| 探索を「正当化」から「特定シグナルの捜索」に寄せすぎない | 非抵触。乖離クレームは探索中に何を探すかではなく、探索後に発見した差分をどう記録するかを規律する。 |
| 探索の自由度を削りすぎない | 非抵触。「どこを読むか」「どの順で読むか」には干渉しない。 |
| 局所的な仮説更新を即座の前提修正義務に直結させすぎない | 非抵触。乖離クレームは「前提を修正せよ」ではなく「差分と前提の対応を明示せよ」であり、前提管理には触れない。 |
| 結論直前の自己監査に新しい必須メタ判断を増やしすぎない | 非抵触。変更は自己監査 (Step 5.5) ではなく、ANALYSIS 本文中のテスト分析行への精緻化であり、結論前チェックポイントは増やさない。 |

全原則に抵触しないことを確認した。

---

## 変更規模の宣言

- 追加行: 1 行
- 削除行: 0 行
- 変更対象セクション: compare テンプレート ANALYSIS OF TEST BEHAVIOR
- hard limit (5 行以内): 適合
