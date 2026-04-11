# Iter-92 Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ: B — 情報の取得方法を改善する**

具体的には「コードの読み方の指示を具体化する（どう探すかを改善する）」に該当する。
Step 4 の対実例トレース要件は、現在「ループ内例外処理や多分岐制御フロー」にのみ適用されている。
しかし、関数の振る舞いが共有可変状態（インスタンス変数、モジュールレベル変数、可変引数）に依存する場合も同種の見落としが起きやすい。これは "overall" の推論品質に直結する汎用的な盲点であり、カテゴリ B の「何を探すかではなく、どう考えるか」を改善する方向と一致する。

---

## 改善仮説

**共有可変状態に依存する関数のトレースに対して、既存の対実例チェック（"if this trace were wrong…"）を適用することで、状態依存による誤 VERIFIED 記録を減らし、全体の推論精度が向上する。**

現在の Step 4 最終ルールは「ループ内例外処理または多分岐制御フロー」を対象に対実例トレースを要求しているが、共有可変状態を読み書きする関数は見た目が単純（分岐がない）でも、実行時の状態によって結果が変わる。このカテゴリを明示的に追加することで、「実行コンテキストに依存した挙動」を見落とす失敗パターンを抑制できる。

---

## SKILL.md の変更内容

### 変更箇所

**Step 4: Interprocedural tracing** の最後のルール（1 行を精緻化）。

#### 変更前

```
- For exception handling inside loops or multi-branch control flows: after recording the inferred behavior, ask "if this trace were wrong, what concrete input would produce different behavior?" Trace that input through the code before finalizing the row.
```

#### 変更後

```
- For exception handling inside loops, multi-branch control flows, or functions whose behavior depends on shared mutable state (instance variables, module-level state, or mutable arguments): after recording the inferred behavior, ask "if this trace were wrong, what concrete input would produce different behavior?" Trace that input through the code before finalizing the row.
```

**変更規模: 1 行（既存行への文言追加）**

---

## 一般的な推論品質への期待効果

以下の失敗パターンを減らすことを期待する。

| 失敗パターン | 減少する理由 |
|---|---|
| 状態依存関数を純粋関数と誤認して VERIFIED 記録する | 「共有可変状態」が明示されることで、初期状態の違いを想定したトレースが促される |
| 変更が共有状態を介して間接的にテスト結果を変える場合に EQUIV と誤判定する | Step 4 の段階で状態依存挙動が精査されるため、ANALYSIS OF TEST BEHAVIOR フェーズでの見落としが減る |
| トレースチェーンが「ある呼び出しまで正常、それ以降は推定」になる | 可変状態依存ノードで対実例問を強制することで、推定だけで VERIFIED を付ける行動を抑制する |

対象は全モード（compare / localize / explain / audit-improve）であり、特定の判定方向への優遇はない。

---

## failed-approaches.md との照合

| 原則 | 抵触の有無 | 理由 |
|---|---|---|
| #1 判定の非対称操作 | なし | EQUIV / NOT_EQ の双方向に等しく適用される |
| #2 出力側の制約 | なし | 推論プロセス（Step 4 でのトレース行動）を変える変更であり、出力形式の制約ではない |
| #3 探索量の削減 | なし | トレースの対象範囲を拡大する方向 |
| #5 テンプレートの過剰規定 | なし | 「何を記録するか」ではなく「どう検証するか」の精緻化であり、記録対象フィールドの追加ではない |
| #7 分析前の中間ラベル生成 | なし | トレース中の検証要求であり、探索前のカテゴリ分類ではない |
| #8 受動的記録フィールドの追加 | なし | 新フィールドは追加しない。既存の能動的検証手順を適用条件に共有可変状態を追加するのみ |
| #9 メタ認知的自己チェック | なし | 「自分はやったか？」という自己評価ではなく、「この入力を通したらどうなるか」という外部的に検証可能な行動を直接要求する |
| #18 / #19 物理的証拠の義務化 | なし | 引用形式の義務付けではなく、「入力を想定してコードをたどる」という思考実験を要求するのみ |
| #22 具体物の例示が物理的探索目標化 | 軽微なリスクを確認・許容 | 例示した三項目（instance variables, module-level state, mutable arguments）はコード構造のカテゴリであり、既存の "multi-branch control flows" / "exception handling" と同様の抽象度。特定のコード要素を指していないため、原則 #22 の「具体物」には該当しないと判断する |
| その他 (#4, #10, #11, #12, #13, #14–#17, #20–#21, #23–#27) | なし | 探索順序・ゲート・対称性・クエリ拡張などとは無関係 |

---

## 変更規模の宣言

- 変更行数: **1 行**（既存行への文言追加・精緻化）
- 新規ステップ: なし
- 新規フィールド: なし
- 新規セクション: なし
- 削除行: なし
- ハードリミット（5 行）に対する余裕: 4 行
