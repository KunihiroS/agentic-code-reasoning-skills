# Iter-37 Proposal

## Exploration Framework Category: B
### カテゴリ内のメカニズム選択理由

カテゴリ B は「情報の取得方法を改善する」と定義され、次の三つのメカニズムを含む:
- コードの読み方の指示を具体化する
- 何を探すかではなく、どう探すかを改善する
- 探索の優先順位付けを変える

今回選択するメカニズムは「探索の優先順位付けを変える」である。

compare モードの STRUCTURAL TRIAGE において S3 は大規模パッチへの対処を定めているが、
小・中規模パッチに対して「どの差分を先に読むか」の優先付けが明示されていない。
エージェントは差分をファイル出現順に機械的に処理しがちであり、
意味的に中心的な変更（ロジック変更、制御フロー変更）を
付随的な変更（フォーマット、コメント、インポート整理）と同列に扱ってしまう。
これは overall スコアを下げる主因の一つである「証拠収集の方向性の分散」
—— 関係の薄い差分に注意を使い、核心的な差分の証拠収集が浅くなる —— を引き起こす。

先に意味変化の大きい差分を読むよう優先順位を明示することで、
限られた探索ステップを核心的な証拠取得に集中でき、
全体的な推論品質の向上が見込まれる。

---

## 改善仮説

compare モードの構造的トリアージ段階で、差分の種別（ロジック変更 vs 付随的変更）に
基づく読解優先順位を明示することで、エージェントが限られた探索コストを
意味的に中心的な変更の検証に優先投入できるようになり、
evidence の収集精度が向上して全体的な判定精度が上がる。

---

## SKILL.md のどこをどう変えるか

### 変更対象

compare モードの STRUCTURAL TRIAGE、S3 の説明行。

### 変更前

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

### 変更後 (追加分: 1行, 変更行: 1行、計2行の変更)

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
      For any size patch, read logic/control-flow changes before
      formatting, comment, or import-only changes.
```

### 説明

既存の S3 行の末尾に 1 文（2行）を追記するのみ。
「大規模パッチ向けの既存指示」はそのまま維持しつつ、
「全サイズパッチ共通の読解優先順位」を補足として付加する。
新規セクション・新規フィールド・新規ステップの追加はなし。

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. 付随的差分（フォーマット・コメント・インポート変更）を詳細にトレースした後、
   核心的なロジック変更のトレースが浅くなり EQUIVALENT を誤判定するケース
   （overall および equiv カテゴリの失敗に直結）

2. 複数ファイルにまたがる変更で、出現順に読み進めた結果、
   最も意味的に重要な変更が後回しになり、探索が途中で収束してしまうケース

3. 「差分があるがテスト影響なし」と早期に判定してしまうケース —— ロジック変更を
   先に確認する順序制約が、Guardrail #4（微妙な差分を軽視しない）の遵守を補強する

### 回帰リスク

変更範囲は S3 の補足 1 文のみ。
NOT_EQUIVALENT 判定（既に 100% 正答）が影響を受けるとすれば、
ロジック変更が先に見つかるため EQUIVALENT 誤判定がしにくくなる方向であり、
スコアを下げる方向の回帰は考えにくい。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 該当するか | 判定 |
|------|-----------|------|
| 次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける | 今回の変更は「証拠の種類」ではなく「読む順序の優先付け」を示す。種類の固定ではない | 抵触なし |
| 探索の自由度を削りすぎない | 優先順位は「先に読む」であり「後の変更を読まない」ではない。探索の全体幅は変わらない | 抵触なし |
| 仮説更新を前提修正義務に直結させすぎない | 本変更は探索順序のみを扱い、仮説更新・前提管理とは無関係 | 抵触なし |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | 本変更は Step 3 以前の STRUCTURAL TRIAGE 内の補足であり、Step 5.5 の自己監査には影響しない | 抵触なし |

全原則との照合: **抵触なし**

---

## 変更規模の宣言

- 変更行数: **2行追加**（既存行の削除なし）
- hard limit（5行）以内: **適合**
- 新規ステップ・新規フィールド・新規セクションの追加: **なし**
