# Iteration 8 — Proposal

## Exploration Framework カテゴリ: C（強制指定）

### カテゴリ内のメカニズム選択理由

カテゴリ C には 3 つのメカニズムが定義されている:

1. テスト単位ではなく関数単位・モジュール単位での比較
2. 差異の重要度を段階的に評価する
3. 変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う

今回は **メカニズム 2「差異の重要度を段階的に評価する」** を選択する。

理由:

現在の compare チェックリストには次の指示がある:

  "When a semantic difference is found, trace at least one relevant test through
   the differing code path before concluding it has no impact"

この指示はトレースの義務付けとして有効だが、「見つけた差異がどの種類か」を
問わずすべてに同等のコストを課す。結果として 2 つの失敗パターンが起きやすい:

- 軽微な差異（構造的・順序的であり意味が等価なもの）を同等に深追いして、
  より重大な差異のトレースに割く注意力が減る。
- 逆に「この差異は自明に無影響」と早合点して、フルトレースを省略する
  （Guardrail #4 の失敗パターン）。

重要度分類を先に行う枠組みを追加すると、エージェントは差異を目にした瞬間に
「これは制御フロー・値生成系か、構造的同一意味系か、装飾的変更か」を明示的に
ラベリングしてから次の行動を決める。このラベルが「フルトレース必須 / 意味的
中立性の明示的正当化が必要 / スキップ可」の判断をガイドする。

メカニズム 1（比較粒度）はすでに STRUCTURAL TRIAGE で部分的にカバーされている。
メカニズム 3（変更カテゴリ分類）は STRUCTURAL TRIAGE の S1–S3 で扱える範囲と
重複が大きく、compare モードの判定精度向上への寄与が相対的に小さい。
そのためメカニズム 2 を選択する。


## 改善仮説

「意味的差異を見つけた時点で重要度カテゴリを明示的に分類させることで、
 エージェントが制御フロー・値生成系の差異を見落とすリスクと、
 意味的に中立な差異に対して不要なフルトレースを行うコストの両方を削減できる。」


## SKILL.md のどこをどう変えるか

### 変更対象

SKILL.md の Compare checklist 内の以下の 1 行:

  変更前 (line 258):
    - When a semantic difference is found, trace at least one relevant test
      through the differing code path before concluding it has no impact

  変更後 (2 行に精緻化):
    - When a semantic difference is found, first classify it as:
      (a) control-flow or value-producing change, (b) structural/ordering change
      with identical semantics, or (c) cosmetic change.
      Category (a) requires tracing at least one relevant test through the
      differing path. Categories (b)/(c) require explicit written justification
      of semantic neutrality before skipping the trace.

### 変更規模の宣言

- 削除行: 1 行
- 追加・変更行: 4 行（hard limit 5 行以内、適合）
- 新規ステップ・新規フィールド・新規セクション: なし
- 既存行への精緻化のみ: yes


## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **Guardrail #4 型: 微細差異の軽率な棄却**
   差異を見つけた後「影響なし」と素早く判断してトレースを省略するケースに対し、
   category (a) の差異には明示的トレースを義務化することで抑制できる。

2. **過剰トレースによる注意力散漫**
   category (b)/(c) の差異を「意味的中立性の正当化」だけで処理できるようにすることで、
   真に重要な差異へのトレースコストを節約し、全体的な推論精度が上がりやすくなる。

3. **全体的な推論品質 (overall) の向上**
   EQUIVALENT / NOT_EQUIVALENT 判定のどちらにも、差異の重要度評価精度が直接影響する。
   分類ステップの追加は両方向の判定精度を底上げする汎用効果がある。


## failed-approaches.md の汎用原則との照合

### 原則 1: 「探索を特定シグナルの捜索へ寄せすぎる変更は避ける」

今回の変更は「差異が見つかった後の処理手順」を精緻化するものであり、
探索フェーズ（何をどの順で読むか）を制約するものではない。
分類ステップは差異という観測済みの事実に対する後処理であり、
確認バイアスを強めたり代替経路の探索を妨げたりする性質を持たない。
-> 抵触しない。

### 原則 2: 「探索の自由度を削りすぎない」

追加する分類は category (a)/(b)/(c) という 3 つの開いたラベルであり、
特定のコードパターンや言語構造に縛られていない。
category (b)/(c) の処理も「スキップ禁止」ではなく
「意味的中立性の正当化を書く」という軽量な要件に留めている。
探索の自由度は実質的に削られない。
-> 抵触しない。


## 変更規模の宣言（再掲）

削除: 1 行
追加: 4 行
合計変更: 4 行 (hard limit 5 行以内)
新規セクション・ステップ・フィールド: なし
