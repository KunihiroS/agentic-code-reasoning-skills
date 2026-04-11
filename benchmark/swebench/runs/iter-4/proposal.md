# Iter-4 Proposal

## Exploration Framework カテゴリ: E（表現・フォーマットの改善）

### カテゴリ E 内でのメカニズム選択理由

カテゴリ E には「曖昧文言の具体化」「簡潔化」「例示の追加・改善」の 3 つのメカニズムがある。
今回は **「例示を追加して適用範囲の曖昧さを解消する」** メカニズムを選択した。

対象箇所は Step 4（Interprocedural tracing）の Rules の最終行である。
現行文言は発火条件を「exception handling inside loops or multi-branch control flows」と
限定列挙しており、この列挙に含まれないコントロールフロー（単独の条件分岐、ディスパッチ
テーブル等）で反証的問いかけが省略される誤読を招きうる。
条件を「non-trivial control flows」と上位概念で表現したうえで、旧来の例示と
それ以外のパターンを括弧内に列挙することで、意図する適用範囲を明示する。

これは新規ステップでも新規セクションでもなく、既存1行の文言精緻化のみである。


## 改善仮説

「反証的トレース指示の発火条件が限定的な例示に固定されているとき、
その例示に合致しない非自明なコントロールフローでは反証ステップが省略され、
誤ったトレース結論が Step 5 に流れ込む。発火条件を上位概念で再定義し
例示を充実させることで、反証的問いかけの適用範囲が正しく広がり、
全体的なトレース精度が向上する。」


## 変更箇所と変更内容

### 変更対象

SKILL.md > Step 4: Interprocedural tracing > Rules（最終行）

### 変更前（1行）

```
- For exception handling inside loops or multi-branch control flows: after recording the inferred behavior, ask "if this trace were wrong, what concrete input would produce different behavior?" Trace that input through the code before finalizing the row.
```

### 変更後（1行）

```
- For non-trivial control flows (loops, conditionals, exception handlers, dispatch tables): after recording the inferred behavior, ask "if this trace were wrong, what concrete input would produce different behavior?" Trace that input through the code before finalizing the row.
```

### 変更の要点

- 「exception handling inside loops or multi-branch control flows」
  → 「non-trivial control flows (loops, conditionals, exception handlers, dispatch tables)」
- 上位概念（non-trivial control flows）で意図を包括的に定義した上で、
  代表的なパターンを括弧内に例示した。
- 旧来の例示（exception handling, multi-branch）は括弧内に吸収されている。
- 既存1行の文言を置き換えるのみ。追加行・削除行ゼロ。


## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **単純条件分岐での反証省略**
   ループや例外処理を含まない、単独の if/else や switch/match で
   条件ごとに返り値が異なるケースで、反証的問いかけが適用されていなかった。
   変更後は「conditionals」が明示されるため発火する。

2. **ディスパッチテーブル・マッピング構造での見落とし**
   設定ディクショナリや関数ポインタテーブルを経由するディスパッチを
   「exception handling / multi-branch」と認識しにくかった。
   変更後は「dispatch tables」が明示されるため発火する。

3. **compare モードでの EQUIVALENT 過判定**
   2 つの実装の差異が単純な条件分岐の中にある場合、トレースが楽観的に
   完了してしまい、Step 5 の counterexample 探索に悪い前提が渡されることがあった。
   発火条件の拡大により、中間ノードのトレース精度が上がり、
   overall 精度（EQUIV/NOT_EQ 両方）の改善が期待できる。

### 影響しない（悪化させない）パターン

- 発火条件が拡大されるだけで、新たな義務的証拠収集や物理的引用要求は追加しない。
  よって探索予算の枯渇（原則 #18, #19, #26）は引き起こさない。
- 判定方向（EQUIV / NOT_EQ）に非対称な作用はない。原則 #1 に非抵触。


## failed-approaches.md 汎用原則との照合

| 原則番号 | 内容の要旨 | 本提案との関係 |
|----------|-----------|----------------|
| #1 | 判定の非対称操作 | 非抵触。発火条件拡大は EQUIV/NOT_EQ 両方に対称に作用する |
| #2 | 出力側の制約は効果がない | 非抵触。入力トレースの精度改善（処理側の改善）である |
| #3 | 探索量の削減は有害 | 非抵触。発火条件を広げており探索を削減しない |
| #4 | 同方向の変更は表現が変わっても同じ結果 | 非抵触。方向は「発火条件の正確化」であり過去に試みた方向と異なる |
| #5 | 入力テンプレートの過剰規定 | 非抵触。記録フィールドを増やさず、条件の精度を上げるのみ |
| #7 | 中間ラベル生成によるアンカリング | 非抵触。ラベルではなくトレース条件の定義変更である |
| #8 | 受動的な記録フィールドの追加 | 非抵触。フィールド追加なし。既存の反証問いかけの発火範囲変更のみ |
| #9 | メタ認知的自己チェックの限界 | 非抵触。自己チェックの追加ではない |
| #16 | ネガティブプロンプトによる禁止の過剰適応 | 非抵触。禁止・制限の追加はしていない |
| #18 | 特定証拠カテゴリへの物理的裏付け要求 | 非抵触。物理的引用の義務化は追加していない |
| #22 | 抽象原則での具体物の例示が物理的探索目標に過剰適応 | **要注意。括弧内の例示（loops, conditionals...）が物理的ターゲットとして過剰解釈されるリスクがある** |
|    |  | 緩和策: 括弧内は「control flow の類型」の例示であり、特定のコード要素名（関数名・変数名等）ではない。抽象的な類型として列挙されているため、原則 #22 の「コード要素を物理的探索目標として特定する」ケースとは異なる |

全 27 原則のうち、直接の抵触なし。原則 #22 については緩和策により抵触しないと判断する。


## 変更規模の宣言

- 変更行数: 1行（既存行の文言置き換え）
- 追加行: 0
- 削除行: 0（置き換えのため削除行としてカウントしない）
- 新規ステップ/フィールド/セクション: なし
- Hard limit（5行以内）: 適合
