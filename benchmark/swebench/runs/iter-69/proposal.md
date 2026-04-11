# iter-69 proposal

## Exploration Framework カテゴリ

**カテゴリ E: 表現・フォーマットを改善する**

選定理由: `not_eq` の失敗はしばしば「探索で差異を見つけたにもかかわらず判定を翻す」という後退ドリフトで生じる。探索フェーズの変更や新ステップ追加ではなく、テンプレートの既存フィールド間のアノテーションを精緻化することで、ANALYSIS と COUNTEREXAMPLE の構造的接続を強化できる。これは記述オーバーヘッドを増やさず、認知的な足場を整える Category E の典型的な適用である。

---

## 改善仮説

ANALYSIS セクションで特定のテストについて `Comparison: DIFFERENT` という結論が得られていても、エージェントは COUNTEREXAMPLE セクションに進んだ際に当該クレームを参照せず一から再構築を試みる。この再構築時に不確実性が高まると差異の立証を途中で断念し、証拠が揃っているにもかかわらず EQUIVALENT 側に後退する（解析ドリフト）。COUNTEREXAMPLE セクションのヘッダーに「ANALYSIS で DIFFERENT と記録したクレームを起点とすること」を明示すれば、このドリフトを構造的に防止できる。

---

## 変更内容

### 変更対象

`SKILL.md` — Compare モードの Certificate template 内 `COUNTEREXAMPLE` セクションの見出し行（1行）。

### 変更前

```
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT):
```

### 変更後

```
COUNTEREXAMPLE (required if claiming NOT EQUIVALENT — identify the specific test where Comparison was DIFFERENT in ANALYSIS above, and build this trace from that claim):
```

### 変更規模の宣言

**変更行数: 1行**（既存行の文言追加）。削除行なし。5行制限に対して余裕を持って適合。

---

## 期待効果

| 失敗パターン | 現状 | 改善後 |
|---|---|---|
| ANALYSIS で DIFFERENT を見つけた後、COUNTEREXAMPLE 再構築時に後退する | ANALYSIS と COUNTEREXAMPLE の接続が明示されていない | COUNTEREXAMPLE が ANALYSIS クレームの参照を起点とするため後退しにくくなる |
| 差異を発見したが十分な根拠がないと判断し EQUIVALENT を選ぶ | counterexample 構築の起点が曖昧 | 既存クレームを転用する経路が明確になり、立証の達成可能性が上がる |

対称性の担保: この変更は NOT_EQUIVALENT 判定を出すための追加的な証拠要件を設けるものではない。ANALYSIS 内で既に行ったトレースを COUNTEREXAMPLE 構築に活用することを指示するのみであり、判定閾値は変化しない。EQUIVALENT 判定経路（NO COUNTEREXAMPLE EXISTS）への影響もない。

---

## failed-approaches.md との照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | 適合。閾値を変えず、ANALYSIS 結果の参照を促すだけ。EQUIVALENT 側の立証責任は変化しない。 |
| #2 出力側の制約 | 適合。「こう答えろ」という出力制約ではなく、推論の構造的接続を改善。 |
| #7 中間ラベル生成によるアンカリング | 適合。分析前のラベル付けではなく、分析後の結果を参照させる。 |
| #8 受動的記録フィールドの追加 | 適合。新フィールドを追加しておらず、検証行動も要求していない。既存セクションへの接続指示のみ。 |
| #9 メタ認知的自己チェック | 適合。自己評価を求める自己チェックではなく、テンプレート間の接続ポインタ。 |
| #12 アドバイザリな非対称指示 | 適合。NOT_EQUIVALENT 側の追加検証を要求しておらず、立証責任を引き上げていない。 |
| #14 条件付き特例探索 | 適合。新たな探索枝を追加しておらず、主比較ループの完結を支援するのみ。 |
| #19 エンドツーエンド完全立証義務 | 適合。ANALYSIS クレームをそのまま転用する経路を示すことで探索予算を節約する方向に作用する。 |

**抵触する原則なし。**
