# Iter-36 Proposal

## Exploration Framework カテゴリ: A (強制指定)

### カテゴリ A 内での具体的メカニズム選択

カテゴリ A の3つのメカニズムのうち、**逆方向推論 (結論から逆算して必要な証拠を特定する)** を選択する。

**選択理由:**

Compare テンプレートは現在、STRUCTURAL TRIAGE → PREMISES → ANALYSIS という前向きの順序で動く。
ANALYSIS セクションでは各テストについて Change A と Change B の振る舞いを個別にトレースし、
最後に COUNTEREXAMPLE CHECK で反証を試みる構造になっている。

この構造では、詳細トレース (ANALYSIS) が「結論を先に持たない状態」で行われるため、
トレースが証拠収集の目的を持ちにくく、中立的な記述に流れやすい。
その結果、微細な差異を発見した後に「これは結果に影響するか」という判断が後付けになる。

逆方向推論を導入すると: STRUCTURAL TRIAGE 完了直後に仮結論 (LIKELY EQUIVALENT / LIKELY NOT EQUIVALENT)
を明示させ、その仮結論を「覆すことを目的として」ANALYSIS を実施させる。
これにより ANALYSIS が証拠収集でも確認でもなく「仮結論への挑戦」として機能し、
見落とされやすい反証候補を積極的に探す動機が生まれる。

逆方向推論はステップの削除でも新規追加でもなく、STRUCTURAL TRIAGE 完了時点に
判断の先行固定を求める記述順序の変更であり、既存行への文言追加として5行以内に収まる。

---

## 改善仮説

STRUCTURAL TRIAGE 完了直後に仮結論を先置きすることで、続く ANALYSIS が
仮結論を覆すことを目的とした証拠探索として機能し、EQUIVALENT 誤判定 (差異を発見しても
その影響を過小評価するパターン) および NOT EQUIVALENT 誤判定 (構造的差異のない
ケースでのノイズ検出) の両方を抑制できる。

---

## SKILL.md のどこをどう変えるか

### 変更対象

SKILL.md の Compare テンプレート内、STRUCTURAL TRIAGE ブロックの末尾
(S3 の記述直後、"If S1 or S2 reveals a clear structural gap..." パラグラフの直前)

### 変更前 (既存行)

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.

If S1 or S2 reveals a clear structural gap (missing file, missing module
```

### 変更後 (文言追加: +2行)

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
  S4: Provisional verdict — before entering ANALYSIS, state LIKELY EQUIVALENT
      or LIKELY NOT EQUIVALENT based solely on S1–S3. The goal of ANALYSIS
      is to challenge this verdict, not to confirm it.

If S1 or S2 reveals a clear structural gap (missing file, missing module
```

### 変更内容の説明

S4 として2行を追加する。新規セクション・新規フィールドではなく、
STRUCTURAL TRIAGE という既存ブロック内の末尾項目として位置づけるため、
「既存ステップへの文言追加・精緻化」の範囲に収まる。

変更規模: 追加2行 (削除0行)。hard limit (5行) 以内。

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

**1. 「差異を発見したが影響しないと判断した」パターン (EQUIVALENT 誤判定)**

現行フローでは ANALYSIS の各テスト分析が証拠収集として始まり、COUNTEREXAMPLE CHECK
で初めて「この差異が影響するか」を問う。このため ANALYSIS 中に差異を見つけても
「軽微かもしれない」という先入観が残りやすい。

S4 で仮結論を先置きすると、仮に LIKELY EQUIVALENT と置いた場合の ANALYSIS は
「それを覆す例があるか」という問いとして動く。差異を見つけた瞬間に
「これは仮結論を崩せるか」という評価が自然に発生し、影響の過小評価を抑制する。

**2. 「構造的には同一だが細部で迷った」パターン (NOT EQUIVALENT 誤判定)**

S1–S3 で構造的ギャップが見つからない場合、S4 では LIKELY EQUIVALENT が自然な仮結論となる。
この仮結論を覆す証拠を探す形で ANALYSIS が動くため、証拠なき NOT EQUIVALENT 判定を
出しにくくなる。

### 維持されるコア構造

番号付き前提、仮説駆動探索、手続き間トレース、必須反証のすべてが維持される。
S4 は STRUCTURAL TRIAGE の一部として機能し、PREMISES 以降のステップを削除・
省略しない。

---

## failed-approaches.md の汎用原則との照合

| 原則 | 本提案との関係 | 判定 |
|------|---------------|------|
| 探索を「特定シグナルの捜索」に寄せすぎない | S4 は「仮結論を覆す証拠」を探す方向性を与えるが、証拠の種類は固定しない。探索経路は探索者に委ねられる | 抵触なし |
| 読解順序の半固定で探索経路を早期に細らせない | S4 は記述タイミング (仮結論を先に書く) の変更であり、どのファイルをどの順に読むかを指定しない | 抵触なし |
| 局所的な仮説更新を前提修正義務に直結させすぎない | S4 は ANALYSIS 開始前の一回限りの仮置きであり、探索中の更新義務ではない | 抵触なし |
| 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない | S4 は STRUCTURAL TRIAGE 内 (結論直前ではなく冒頭フェーズ) に位置し、Step 5.5 の自己監査とは別のポイント | 抵触なし |

すべての原則との照合で抵触なし。

---

## 変更規模の宣言

- 追加行数: 2行
- 削除行数: 0行
- hard limit (5行): **遵守**
- 変更形式: 既存ブロック (STRUCTURAL TRIAGE) への末尾項目追加。新規ステップ・新規セクションの追加には該当しない
