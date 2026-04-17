# Iter-2 Proposal (focus_domain: overall)

## Exploration Framework
- カテゴリ: C. 比較の枠組みを変える
- メカニズム選択理由:
  - `compare` の誤判定は「差分を見つけた」こと自体を“重要な差分”と取り違え、テストの観測点（oracle）に結び付かないまま EQUIV/NOT_EQUIV を早期確定しがち。
  - そこで「差異重要度（oracle可視性）」という比較分類を導入し、同じ証拠（file:line トレース）をより高い識別力で使えるようにする。

## 改善仮説（1つ）
差分を「テストの観測点に影響しうる差分（oracle-visible）」と「表現・構造の差（oracle-invisible）」に分類してから追跡優先度を決めると、差分探索が“重要度の低い差分”に吸い込まれにくくなり、全体の比較判断（overall）の安定性が上がる。

## 現状ボトルネックの診断（SKILL.md 引用 + 誘発する失敗メカニズム 1つ）
該当箇所（Compare テンプレート）:
```
STRUCTURAL TRIAGE (required before detailed tracing):
Before tracing individual functions, compare the two changes structurally:
  S1: ...
  S2: ...
  S3: ...
```
診断:
- 構造差分（S1/S2）とスケール判断（S3）はあるが、「差分の重要度（テスト oracle に結び付くか）」の分類が明示されていない。
- その結果、差分発見→（oracle 連結の薄いまま）“重大差分扱い”となり、(a) NOT_EQUIV の過剰確定（偽 NOT_EQ）または (b) EQUIV 側の反証探索が表層差分に偏って反証が空回り、のどちらかを誘発しうる。

## 変更タイプ
- optional なガイド追加
- 理由: 新しい必須ゲートを増やさず、既存の STRUCTURAL TRIAGE の中で「比較分類（差異重要度）」を“任意の優先度付け”として添えるだけで、探索の自由度を落とさずに差分の扱いを改善できる。

## SKILL.md のどこをどう変えるか（具体）
対象: `## Compare` → `### Certificate template` → `STRUCTURAL TRIAGE` と `### Compare checklist`

提案差分（追加は3行、削除なし）:
```diff
@@
 STRUCTURAL TRIAGE (required before detailed tracing):
 Before tracing individual functions, compare the two changes structurally:
   S1: Files modified — list files touched by each change. Flag any file
       modified in one change but absent from the other.
   S2: Completeness — does each change cover all the modules that the
       failing tests exercise? If Change B omits a file that Change A
       modifies and a test imports that file, the changes are NOT EQUIVALENT
       regardless of the detailed semantics.
   S3: Scale assessment — if either patch exceeds ~200 lines of diff,
       prioritize structural differences (S1, S2) and high-level semantic
       comparison over exhaustive line-by-line tracing. Exhaustive tracing
       is infeasible for large patches and produces unreliable conclusions.
+  OPTIONAL — S4: Difference importance — label each discovered difference as ORACLE-VISIBLE
+      (can change an asserted output/exception/externally visible state) vs ORACLE-INVISIBLE,
+      and prioritize tracing ORACLE-VISIBLE differences to a concrete test oracle first.
@@
 ### Compare checklist
@@
 - Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
+ - Optional: classify differences by oracle-visibility to prioritize which ones must be traced to a concrete assertion
```

## 期待される "挙動差"（compare に効く形）
- 変更前に起きがちな誤り（一般形）:
  - 「意味的に違う」ことを見つけた時点で NOT_EQUIV に寄せ、テストの assertion（oracle）まで結び付けるトレースが薄いまま結論を出す（偽 NOT_EQ を増やす）。
- 変更後にその誤りが減るメカニズム:
  - 差分を oracle-visible / oracle-invisible に分類することで、比較の焦点が「oracle に効く差分の実証（反証可能な形）」へ自動的に寄り、差分の“重要度取り違え”が減る。
- その結果として減る見込みの誤判定（片方向最適化にならない形で）:
  - 主に「偽 NOT_EQ（本当は EQUIV だが差分の存在だけで NOT_EQ と誤判定）」が減る。
  - 同時に、oracle-visible を優先して結び付けるため「偽 EQUIV（本当は NOT_EQ だが差分を oracle まで持って行けず見落とす）」も減らしやすい（見落としが起きるのは“oracle 連結の不足”なので、優先度付けがそこを補う）。

## 最小インパクト検証（思考実験で可）
- ミニケース A（変更前は揺れる/誤るが、変更後は安定）:
  - 2つの実装に、内部データ構造や表現の違い（順序・キャッシュ・補助関数の分割など）はあるが、テストが観測するのは戻り値・例外・外部状態の一部だけ。
  - 変更前: 内部差分を見て NOT_EQ 寄りに判断が揺れる。
  - 変更後: その差分を oracle-invisible とラベルし、oracle-visible に当たる差分（もしあれば）だけを assertion まで結び付けるため、結論が「テスト oracle ベース」に安定する。
- ミニケース B（逆方向の誤判定を誘発しうる状況 + 悪化しない理由/回避策）:
  - 内部差分が、間接的に外部観測へ影響する（例: 例外種別、ログ/メトリクス、順序、タイミング、グローバル状態の更新）タイプで、テストがそれを観測している可能性がある。
  - 悪化しない理由/回避策:
    - S4 の定義を「asserted output/exception/externally visible state」と広めに書き、例外・外部状態・順序等も oracle-visible に含めうるようにしている。
    - さらに S4 は OPTIONAL であり、既存の「Trace each test…」「Provide a counterexample…」を置き換えないため、oracle 連結の要求（反証可能性）は弱まらない。

## 一般的な推論品質への期待効果
- 「差分の存在」と「差分の重要度」を混同する失敗パターン（比較における salience バイアス）を減らす。
- テスト oracle への結線を優先することで、根拠の薄い結論（特に NOT_EQ の断定）を抑制し、証拠駆動の比較が増える。

## トレードオフ（overall 観点）
- 悪化しうる経路（1つ）:
  - oracle-visible を狭く解釈しすぎると、本来観測される差分（例外の型/メッセージ、外部状態更新、順序）を oracle-invisible と誤分類して偽 EQUIV を増やしうる。
- 新しい必須手順を増やさずに避ける工夫:
  - S4 の括弧書きを「output/exception/externally visible state」として広くし、分類の取りこぼしを減らす（“定義の精緻化”ではなく、optional ガイド内の表現で吸収）。
  - OPTIONAL と明記し、探索の自由度を維持する（状況に応じて分類を更新できる）。

## failed-approaches.md との整合（1〜2点だけ具体）
- 「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」に整合:
  - S4 は“探す証拠”を固定せず、既に見つかった差分の扱い（重要度分類）だけを補助する。証拠探索を特定シグナル検索へ寄せない。
- 「探索の自由度を削りすぎない」に整合:
  - 追加は OPTIONAL で、読解順序や特定の追跡方向を半固定化しない。既存の手続き（テストごとのトレース/反証）を置換しない。

## 変更規模の宣言
- 追加: 4行（うち Compare テンプレートに3行、チェックリストに1行）
- 削除: 0行
- 追加行は hard limit（5行以内）を満たす。
