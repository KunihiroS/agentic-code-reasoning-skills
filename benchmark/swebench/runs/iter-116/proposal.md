# Iter-116 Proposal

## Exploration Framework カテゴリ: C (強制指定)

カテゴリ C「比較の枠組みを変える」の中から、今回は **差異の重要度を段階的に評価する** メカニズムを選択する。

### メカニズム選択の理由

compare モードの EQUIV 誤判定は次の二段構えの失敗で生じる:

1. 意味的差異が存在する (Guardrail #4 が発動して差異を見つける)
2. その差異が **テストの観測点 (assertion の評価式) まで伝播するか否か** の判断が粗い

現在の `EDGE CASES RELEVANT TO EXISTING TESTS` セクションでは、各エッジケースの最終判定を
`Test outcome same: YES / NO` という二値で記録する。しかしこの二値は
「差異が存在すること」と「差異がテスト結果を変えること」を区別していない。
差異の存在を確認した段階で NO と記入しがちになり、観測境界への到達可否を
判断しないまま NOT_EQ に流れる。これが equiv 精度を損なう主要因の一つである。

カテゴリ C の「差異の重要度を段階的に評価する」メカニズムは、
差異の発生地点とテスト観測点の間の距離・伝播経路を明示させることで、
この粗さを構造的に解消できる。

---

## 改善仮説 (1 つ)

**エッジケース判定において「差異の存在」と「差異のテスト観測点への伝播」を
分離して評価させることで、差異があっても観測されない EQUIV ケースの
誤 NOT_EQ 判定が減少し、equiv 精度が向上する。**

---

## SKILL.md への具体的な変更

### 変更箇所

compare モードの Certificate template 内、`EDGE CASES RELEVANT TO EXISTING TESTS` ブロック。

### 変更前

```
  E[N]: [edge case]
    - Change A behavior: [specific output/behavior]
    - Change B behavior: [specific output/behavior]
    - Test outcome same: YES / NO
```

### 変更後

```
  E[N]: [edge case]
    - Change A behavior: [specific output/behavior]
    - Change B behavior: [specific output/behavior]
    - Difference propagates to test assertion: YES / NO — [how or why not]
    - Test outcome same: YES / NO
```

### 差分サイズ

追加行: 1 行 (`Difference propagates to test assertion: YES / NO — [how or why not]`)
削除行: 0 行
合計変更: **1 行** (hard limit 5 行以内)

---

## 期待効果: どのカテゴリ的失敗パターンが減るか

### 失敗パターン 1: 意味的差異の存在 → 即 NOT_EQ の推論ショートカット

差異が観測点まで伝播するかを問うフィールドを挿入することで、
エージェントは「差異を見つけた」→「テスト結果に影響する」の
論理的ステップを明示的に踏まざるを得なくなる。
これは docs/design.md が指摘する「Subtle difference dismissal」の逆パターン、
つまり「差異の過剰評価」を抑制する効果を持つ。

### 失敗パターン 2: EQUIVALENT の正当化不足

NO_COUNTEREXAMPLE_EXISTS セクションと組み合わせると、
伝播経路の記述が「なぜ反例が存在しないか」の構造的根拠となり、
EQUIVALENT 判定の信頼性が上がる。

### 影響を受けない既存の動作

- NOT_EQ が正しい場合: `Difference propagates to test assertion: YES` と記述し
  `Test outcome same: NO` に自然に至るため、正しい NOT_EQ 判定は阻害されない。
- 探索量は変わらない: 伝播経路の確認は主比較ループ (テストのトレース) の
  一部として自然に行われる行為であり、独立した追加探索を義務化しない。
  (failed-approaches #25 への抵触なし)

---

## failed-approaches.md との照合

| 原則 | 抵触判定 | 理由 |
|------|----------|------|
| #1 判定の非対称操作 | なし | EQUIV/NOT_EQ 両方向に等しく適用される。伝播 YES → NOT_EQ、伝播 NO → EQUIV へのシグナルを対称に与える |
| #2 出力側の制約 | なし | 「こう答えろ」ではなく、推論の中間ステップで何を確認するかを明示させる変更 |
| #3 探索量の削減 | なし | フィールド追加であり探索を削減しない |
| #4 同方向の変更 | なし | 既存の NO/YES 二値判定を精緻化する方向は過去にとられていない |
| #5 入力テンプレートの過剰規定 | なし | 「何を記録するか」の制限ではなく、差異評価の粒度を上げる |
| #7 中間ラベルのアンカリング | なし | 変更のカテゴリ分類 (リファクタリング等) を事前に行わせる変更ではない。伝播経路の確認は分類ラベルではなく因果的検証 |
| #8 受動的記録フィールドの追加 | 要注意 → なし | 新規テーブル列の追加ではなく、既存フィールド (`Test outcome same`) の前に因果的な問いを挿入する形。記述を埋めるには実際のコードパスを確認する必要があり、能動的な検証行動を誘発する |
| #17 中間ノードの義務化 | なし | 最終観測点 (テストアサーション) への伝播を問うのであり、中間ノードの局所挙動を義務化していない |
| #18/#26 物理的裏付けの要求 | なし | `file:line` の引用を義務化していない。`[how or why not]` は自由記述であり、引用の有無は任意 |
| #25 事前検証手順の義務化 | なし | テスト選定前に走るゲートではなく、主比較ループ内のエッジケース分析の一部として機能する |

---

## 変更規模の宣言

- 追加行数: 1
- 変更行数: 0
- 削除行数: 0
- 合計 (追加 + 変更): **1 行** ← hard limit 5 行以内を満たす
