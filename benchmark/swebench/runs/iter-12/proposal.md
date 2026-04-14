# Iter-12 Proposal

## Exploration Framework カテゴリ: A（強制指定）

### カテゴリ A 内での具体的メカニズム選択

カテゴリ A の三つのメカニズムのうち、今回は「逆方向推論 (backward reasoning)」を選択する。

**選択理由**

compare モードの失敗パターンを整理すると、主要な失敗源は「EQUIVALENT 誤判定」である。
エージェントは Change A / B を順方向にトレースし、"両者で問題のある動作は見当たらない"
と判断した時点で EQUIVALENT に収束しやすい。

逆方向推論を導入することで、「もし NOT EQUIVALENT であれば、どのテストでどのアサーションが
異なる結果を返すか？」という問いを先行させる。この問いへの答えが空であることを確認してから
初めて EQUIVALENT 結論を許可する構造にする。

これは既に Step 5 の COUNTEREXAMPLE CHECK / NO COUNTEREXAMPLE EXISTS に潜在しているが、
現行 SKILL.md では「結論直前」の任意的なチェックとして後置されている。逆方向の問いを
STRUCTURAL TRIAGE の直後 — 詳細トレースの前 — に前置することで、EQUIVALENT 収束バイアスを
構造的に抑制できる。

NOTE: これは新規ステップではなく、既存 STRUCTURAL TRIAGE 行への文言精緻化である。

---

## 改善仮説

「証拠探索を開始する前に、NOT EQUIVALENT であれば存在するはずの発散証拠を言語化させることで、
EQUIVALENT 収束バイアスが抑制され、等価判定の精度（特に false positive の削減）が向上する。」

---

## SKILL.md の変更内容

### 変更箇所

compare モード `STRUCTURAL TRIAGE` ブロックの S3 直後、`PREMISES:` の直前に
1 行の逆方向問いの指示を追記する。

**変更前 (SKILL.md line 190-196):**

```
If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.

PREMISES:
```

**変更後:**

```
If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.

Before detailed tracing, state: "If NOT EQUIVALENT, which test and which
assertion would diverge, and why?" — then trace that path first.

PREMISES:
```

### 変更行数の宣言

追加: 2 行（hard limit 5 行以内、適合）
削除: 0 行

---

## 期待効果

### 失敗パターンとの対応

| 失敗パターン | 改善前 | 改善後 |
|---|---|---|
| EQUIVALENT 誤判定 (false positive) | 順方向トレースで差異未発見 → EQUIVALENT | 逆方向問いが発散候補を先に言語化 → 見落とし抑制 |
| 微妙な差異の却下 (Guardrail #4) | 差異発見後に「影響なし」と短絡 | 発散アサーションを先に特定するため「影響なし」の短絡が起きにくい |

### 全体的な推論品質への効果

- overall: EQUIVALENT 方向への収束バイアスが減り、両方向均等な探索になる
- equiv: 逆方向問いで「発散証拠がない」ことを積極的に確認するため、正当な EQUIVALENT 判定の
  信頼性も上がる（確認的バイアス減少）
- not_eq: 発散アサーションを先に特定することで NOT EQUIVALENT の根拠が明確になる

---

## failed-approaches.md 汎用原則との照合

| 原則 | 抵触可否 | 根拠 |
|---|---|---|
| 探索すべき証拠の種類をテンプレートで事前固定しすぎない | 抵触なし | 今回の変更は「何を探すか」ではなく「どちらの方向から問うか」を変えるもの。探索すべき証拠の種類を固定するのではなく、問いの方向性を変えるだけ |
| 探索の自由度を削りすぎない | 抵触なし | 逆方向問いは追加的な観点であり、順方向探索を禁止・制約しない |
| 結論直前の自己監査に新しい必須メタ判断を増やしすぎない | 抵触なし | 今回の変更は「結論直前」ではなく「STRUCTURAL TRIAGE 直後 / 詳細トレース前」への前置。Step 5.5 の変更ではない |

全原則と非抵触を確認。

---

## 変更規模の宣言

- 追加行数: 2 行
- 削除行数: 0 行
- hard limit (5 行) 以内: YES
