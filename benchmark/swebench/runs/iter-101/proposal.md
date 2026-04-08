# Iter-101 改善提案

## Exploration Framework カテゴリと選定理由

**カテゴリ E — 表現・フォーマットを改善する**

対象ドメインは `equiv`（EQUIVALENT と正しく判定する精度の向上）。

`compare` モードで EQUIVALENT を結論づける際、エージェントは `NO COUNTEREXAMPLE EXISTS` セクションの `Searched for:` フィールドに沿って反証探索を行う。現在の文言 "propagate to a test assertion" は構造的到達（コード差分がアサーションへのパス上に存在するか）と機能的到達（そのコード差分がアサーションの PASS/FAIL 結果を変えるか）を曖昧に混在させている。エージェントがこれを構造的到達と解釈した場合、テスト結果は同一でも「差分がアサーション経路上にある」という理由で誤って NOT_EQUIVALENT を返す可能性がある。これは EQUIV 精度の主要な失敗要因であり、カテゴリ E の「曖昧な指示をより具体的な言い回しに変える」によって対処できる。

---

## 改善仮説

`NO COUNTEREXAMPLE EXISTS` セクションの反証探索目標を「アサーション経路への構造的到達」から「テストアサーションにおける異なる観測可能な結果の有無」へと精緻化することで、エージェントはコードパスの差異とテスト結果の差異を明確に区別できるようになり、実際には同一の観測可能な結果をもたらす実装差分を誤って NOT_EQUIVALENT と判定する頻度が減少する。

---

## SKILL.md への変更内容

### 変更箇所

`Compare` セクション、`NO COUNTEREXAMPLE EXISTS` テンプレート内の `Searched for:` フィールド（現行ファイルの該当行）。

**変更前:**
```
    Searched for: [whether the semantic differences between A and B propagate to a test assertion — which differences were checked and which assertion points they were traced against]
```

**変更後:**
```
    Searched for: [whether the semantic differences between A and B produce different observable outcomes at a test assertion — which differences were checked and what final values or behaviors were compared at each assertion point]
```

### 変更の意図

- "propagate to a test assertion" → "produce different observable outcomes at a test assertion"  
  観測可能な結果（PASS/FAIL）の差異を問うことで、構造的経路の有無ではなく機能的影響の有無へと焦点を移す。

- "which assertion points they were traced against" → "what final values or behaviors were compared at each assertion point"  
  アサーション地点における最終値・振る舞いの比較を求めることで、既に `ANALYSIS OF TEST BEHAVIOR` で行ったトレースから直接抽出できる情報を明示化する。認知負荷の増加ではなく、既存トレースの活用方向の明確化である。

---

## 期待効果（失敗パターンの低減）

**低減が期待される失敗パターン:**

1. **コード差分の構造的検出による誤 NOT_EQUIVALENT 判定**  
   「コードパスが異なる → アサーション経路上にある → NOT_EQUIVALENT」という推論連鎖が、「最終的な観測値が同じか否か」という問いに置き換わることで遮断される。

2. **不完全トレースからの判定ジャンプ（docs/design.md §4.3 Incomplete reasoning chains に相当）**  
   "final values or behaviors compared at each assertion point" という問いは、`ANALYSIS OF TEST BEHAVIOR` のトレース結果（C[N].1, C[N].2）から直接導出できるため、追加の探索ターンを消費せず、トレースの中断による UNKNOWN 回避にも寄与する。

**NOT_EQ 精度への影響:**  
`COUNTEREXAMPLE` セクション（NOT_EQUIVALENT 経路）は変更されない。また `NO COUNTEREXAMPLE EXISTS` での探索が「観測結果の差異」を正確に捉えるようになることで、本物の観測差異が存在する場合にはそれが COUNTEREXAMPLE 構築のトリガーとなるため、NOT_EQ 精度は中立か微増が期待される。

---

## failed-approaches.md 汎用原則との照合

| 原則 | 照合結果 |
|------|---------|
| #1 判定の非対称操作 | 適合。変更は `NO COUNTEREXAMPLE EXISTS`（EQUIVALENT 経路）のみを修正するが、立証責任を上げているのではなく、探索目標を tractable な問い（観測可能な結果の比較）に明確化している。 |
| #2 出力側制約の無効性 | 適合。出力ではなく探索内容（何を調べるか）を改善する変更である。 |
| #3 探索量の削減 | 適合。探索を減らしていない。`ANALYSIS` で既に得た値の再利用を促す形での明確化。 |
| #12 アドバイザリな非対称指示 | 適合。負荷を増やすのではなく、既存トレース結果を活用できる問いへ誘導することで、EQUIVALENT 経路の達成可能性を下げていない。 |
| #18 特定証拠カテゴリへの物理的裏付けの要求 | 適合。`file:line` の新規要求は追加していない。 |
| #20 目標証拠の厳密な言い換え | 適合。"propagate" より "produce different observable outcomes" の方が，PASS/FAIL という自明なバイナリ値を指しており，解釈の幅を狭めるのではなく解釈の曖昧さを解消する方向である。 |
| #22 具体物の例示による過剰適応 | 適合。"final values or behaviors" は状態・性質の抽象的な記述であり、特定のコード要素の名前ではない。原則 #22 の推奨形式（状態・性質による指示）に則している。 |
| #26 中間ステップでの過剰な物理的検証要求 | 適合。要求しているのは `ANALYSIS` のトレース結果から読み取れる最終値の比較であり、新規の中間ノード検証ではない。 |

---

## 変更規模の宣言

- 変更行数: **1 行**（既存行の文言精緻化）
- 新規ステップ・新規フィールド・新規セクション: **なし**
- 削除行: **0 行**
- Hard limit（5 行）に対する余裕: **4 行**
