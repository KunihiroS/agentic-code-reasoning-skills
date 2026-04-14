# Iter-38 Proposal

## Exploration Framework カテゴリ: C（強制指定）

カテゴリ C 内のメカニズム選択:
「変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う」

理由: 現行の STRUCTURAL TRIAGE（S1/S2/S3）はファイルの有無と規模の評価に留まり、
変更の意図的カテゴリを明示的に問わない。これは比較の枠組みとして不完全であり、
カテゴリ C の残存改善余地の中で最も明示的に欠けている要素にあたる。
「差異の重要度を段階的に評価する」と「テスト単位ではなく関数単位で比較する」の
両メカニズムは既に S1/S2/テスト毎 ANALYSIS でカバーされているが、変更意図分類は
S3 の「高レベルセマンティック比較」という語が示唆するに留まり、実施を義務付けていない。


## 改善仮説

compare モードにおいて、差分の意図的カテゴリ（リファクタリング・バグ修正・
機能追加）を構造トリアージの段階で明示分類することで、その後の詳細トレースが
「期待される振る舞い変化の方向」を事前に絞り込んだ上で行われるようになり、
見当違いのトレース経路への探索コストを削減しつつ、比較の見落としパターンを
減らせる。


## SKILL.md の変更内容

対象箇所: compare モード の STRUCTURAL TRIAGE、S3 の末尾に2文を追加する。

変更前（S3 最終行まで）:
```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

変更後:
```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
      For any patch size, classify the primary intent of each change
      (refactoring / bug-fix / feature-addition) before detailed tracing;
      this classification anchors the expected direction of behavioral divergence.
```

変更規模: +3行（削除行なし）。hard limit（5行）以内。


## 期待効果

カテゴリ的失敗パターンとの対応:

1. 「細かい差異の無視（Subtle difference dismissal）」の低減:
   変更意図が「バグ修正」と分類されていれば、微妙なセマンティック差異が
   「意図された変化」として認識されやすくなり、Guardrail #4 の適用が
   促進される。

2. overall の比較精度向上:
   等価判定（EQUIV）・非等価判定（NOT_EQ）いずれにおいても、変更意図という
   先行コンテキストを持つことで、ANALYSIS OF TEST BEHAVIOR の記述方向が
   収束しやすくなる。特に EQUIV ケースでは「リファクタリング」分類が
   NO COUNTEREXAMPLE EXISTS の正当化を補強し、NOT_EQ ケースでは
   「バグ修正」分類が COUNTEREXAMPLE の探索対象を特定のテストカテゴリへ
   絞り込む手助けをする。

3. 回帰リスクの低さ:
   この変更は S3 の既存「高レベルセマンティック比較」の精緻化であり、
   既存の S1/S2 チェックや ANALYSIS ループの順序・義務付けを変えない。
   既に正しく判定できているケースへの影響は極小。


## failed-approaches.md の汎用原則との照合

原則1「探索で探すべき証拠の種類をテンプレートで事前固定しすぎる」:
  → 本変更は証拠の種類を固定しない。変更意図の分類は探索の「出発点の文脈設定」
    であり、具体的に何のシグナルを探すかは引き続き仮説駆動で行われる。非抵触。

原則2「探索の自由度を削りすぎない」:
  → 分類はラベル付与であり、その後の探索経路を制限しない。
    どのファイルを読むか・どの順で読むかは既存プロセス通り。非抵触。

原則3「局所的な仮説更新を前提修正義務に直結させすぎない」:
  → 変更意図分類はトリアージ段階の一回限りの操作であり、探索中の仮説更新と
    は独立している。非抵触。

原則4「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」:
  → この変更は Step 5.5（Pre-conclusion self-check）ではなく STRUCTURAL TRIAGE
    （詳細トレースの前段）への追加であり、結論前チェックの増設ではない。非抵触。


## 変更規模の宣言

追加行: 3行
削除行: 0行
合計変更: 3行（hard limit 5行以内 — 適合）
変更種別: 既存 S3 説明行への末尾精緻化（新規ステップ・新規フィールド・新規セクション なし）
