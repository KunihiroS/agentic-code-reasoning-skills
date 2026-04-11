# Iter-25 改善提案（改訂版）

## 0. 前回提案の取り下げと今回の方針

前回提案（Propagation trace — DIFFERENT 時のみ必須）は監査役により却下された。  
却下理由の核心: **実効差分が DIFFERENT / NOT_EQ 側にしか作用せず、BL-2・BL-6 と実質同型**。

今回はその反省を踏まえ、監査役が代替案として示した方向――**`explain` の DATA FLOW ANALYSIS を compare に真に対称移植する**――を実装する。

---

## 1. 選択した Exploration Framework カテゴリ

**カテゴリ F: 原論文の未活用アイデアを導入する**

### 選択理由

- 監査役フィードバックが明示した通り、iter-8（localize の divergence analysis 移植）・iter-9（propagation check 追加）とは**メカニズムが異なる**ことを事前に確認した。
  - iter-8/9 は「Change A と Change B が最初に異なる値を生む点（divergence）を探す」という非対称な出発点を持っていた。違いを探すことを強制するため、DIFFERENT 方向にアンカリングが生じた。
  - 今回は「テストの assertion を決める key value を A・B 両方について独立に追う」という対称な枠組みを採用する。違いの有無とは無関係に、同じ解析を A と B に施す。
- `explain` モードの DATA FLOW ANALYSIS テンプレートは:
  - key variable を選び
  - Created at / Modified at / Used at を対称的に追跡する  
  という枠組みを持つ。これを compare の A・B 両変更に等しく適用することで、**SAME/DIFFERENT どちらの結論にも同じ粒度で作用する共通の中間表現**を生成させる。

---

## 2. 改善仮説（1つ）

**仮説**: Compare モードの `ANALYSIS OF TEST BEHAVIOR` において、各 relevant test の `Claim C[N].1 / C[N].2` を書く前に、テストの assertion を決定する key value（1〜2個）について Change A・Change B 両方で「生成 → 変更 → assertion での値」を対称的にトレースさせる。これにより、エージェントは「コードレベルの差異の発見」ではなく「assertion 到達時点での具体的な値の一致/不一致」を根拠として Claim を書くようになり、EQUIV 偽陽性（コード差異があっても assertion 値は同じ → SAME を見落とす）と NOT_EQ の両方に対して推論の正確度が上がる。

**論拠**:
- `explain` の DATA FLOW ANALYSIS は Created / Modified / Used という3点で変数の意味論的状態を追跡する。これは LLM のコード解析精度を上げる確立された手法（LLMDFA, arXiv:2402.10754 でも subtask decomposition の一環として有効とされる）。
- 現在の `compare` は "trace through code — cite file:line" という指示のみで、特定の変数値が assertion に至るまでどう変化するかを明示させない。このため、中間的な差異を発見した段階で assertion 到達の確認なく DIFFERENT と結論するショートカットが発生しやすい（EQUIV 偽陽性の根本原因）。
- 今回の追加は **A・B 両方に同一形式を適用する**ため、既存の差分（変更前との比較）でも作用方向は対称であり、BL-2（NOT_EQ 立証責任引き上げ）・BL-6（実効非対称）には該当しない。
- key value を **1〜2個に限定**することで、BL-5（前提過剰規定）・BL-8（受動的記録の多量追加）・原則 #3（探索コスト増大）を回避する。

---

## 3. SKILL.md のどこをどう変えるか

### 変更箇所: Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` 内、各テストブロック

#### 変更前

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
               because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
               because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

#### 変更後

```
For each relevant test:
  Test: [name]
  Key value (1-2 variables or return values that determine this test's assertion):
    With A: created [file:line] → last modified [file:line or NONE] → value at assertion [file:line]: [value/state]
    With B: created [file:line] → last modified [file:line or NONE] → value at assertion [file:line]: [value/state]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
               because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
               because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更規模

- テンプレート本体: +3 行（Key value ヘッダー + With A + With B）
- チェックリスト変更: なし
- **合計: 3 行追加**（20 行以内の目安に対して余裕あり）

---

## 4. iter-8 / iter-9 との本質的差異の説明

| | iter-8 | iter-9 | **今回** |
|---|---|---|---|
| 出発点 | A と B の**乖離点**を探す | 乖離から assertion への propagation を確認 | **A と B を独立に**同じ変数について追跡 |
| 方向性 | 「どこで違うか」を探す（DIFFERENT に引力） | 「違いが assertion に届くか」を確認（DIFFERENT 側の義務増） | 「assertion 到達時の値は何か」を両側に等しく問う（中立） |
| 対称性 | 非対称（違いを見つける前提） | 非対称（DIFFERENT 主張への追加要求） | **対称**（A も B も同一形式） |
| BL 抵触 | BL-2 相当の効果が発生 | BL-2 + BL-6 相当 | なし |

---

## 5. EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV（AI が誤って NOT_EQ と判定しているケース）

**予測: 改善**

- Key value のトレースにより、コードレベルの差異があっても assertion に到達する値が A・B で同一であることを確認する機会が生まれる。
- 「A では [file:line] で X が返る、B では Y が返る」という中間的差異の発見だけで DIFFERENT と結論することへの自然な抑制になる（assertion での値が同じなら SAME）。

### NOT_EQ（AI が正しく NOT_EQ と判定しているケース）

**予測: 維持（回帰リスク低）**

- 真の NOT_EQ では、key value の assertion 到達時の値が A と B で異なるため、トレースが DIFFERENT 主張を自然に支持する。追加的な立証責任を課すわけではない（SAME 主張にも同じ形式が適用されるため、非対称な制約にならない）。
- key value 1〜2個の追加記述のみであり、ターンコスト増加は限定的。

### 実効差分の対称性確認

- **SAME 主張に新たに課されること**: Key value を A・B 両方でトレースする（3行追加）
- **DIFFERENT 主張に新たに課されること**: Key value を A・B 両方でトレースする（3行追加・同じ義務）
- → 差分は SAME 側にも DIFFERENT 側にも均等に適用される。原則 #1・#6 に抵触しない。

---

## 6. failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL-# | 内容 | 本提案との関係 |
|------|------|---------------|
| BL-1 | テスト削除を ABSENT 定義追加 | 無関係（定義の変更なし） |
| BL-2 | NOT_EQ 判定の証拠閾値・厳格化 | **非抵触**: 前回提案と異なり、今回は SAME/DIFFERENT 両方に同一の追加要求を課す。NOT_EQ 専用の義務増ではない。 |
| BL-3 | UNKNOWN 禁止 | 無関係 |
| BL-4 | 早期打ち切り | 無関係（探索を減らさない） |
| BL-5 | P3/P4 アサーション形式強化 | 非抵触: Premises の形式変更ではなく ANALYSIS 内の変数追跡。key value を 1〜2個に限定しており、視野制約は最小。 |
| BL-6 | Guardrail 4 の対称化（実効非対称） | **非抵触**: 今回は既存制約の拡張ではなく新規追加で、かつ変更前との差分が SAME と DIFFERENT に均等。 |
| BL-7 | CHANGE CHARACTERIZATION（中間ラベル生成） | 非抵触: 分析前のラベル付けではなく、各テスト分析内での変数値追跡。 |
| BL-8 | Relevant to 列の追加（受動的記録） | **要注意**: 受動的記録に落ちないよう key value を 1〜2個に限定し、Claims に直接使う値だけに絞る設計。単なる関係性の記述（BL-8）ではなく、assertion 到達時の具体的な値（file:line付き）を要求する点で能動的。 |
| BL-9 | Trace check 自己評価 | 非抵触: 自己評価フィールドではなく、客観的な変数値と file:line を要求。 |
| BL-10 | Reachability ゲート | 非抵触: YES/NO ゲートではなく、変数値の具体的追跡。 |
| BL-11 | Outcome mechanism 注釈（アンカリング） | 非抵触: 汎用メカニズムの列挙ではなく、テスト固有の key value を選ばせる。アンカリングの原因となる「固定カテゴリ」を導入しない。 |
| BL-12 | テストソース先読みの固定順序 | 非抵触: 探索の順序を固定しない。変数を A・B それぞれでトレースする順序は自由。 |

### 共通原則との照合

| 原則 # | 内容 | 照合結果 |
|--------|------|---------|
| #1 | 判定の非対称操作 | **非抵触**: SAME・DIFFERENT 両方の主張に同一の key value トレースを要求。 |
| #2 | 出力側の制約は効果なし | 非抵触: 「こう答えろ」ではなく「この変数を追え」という探索指示。 |
| #3 | 探索量の削減は有害 | 非抵触: 探索量は増える方向（key value のトレース追加）。 |
| #4 | 同方向の変更は同結果 | 非抵触: iter-8/9 とはメカニズムが本質的に異なる（対称追跡 vs 非対称乖離探索）。 |
| #5 | 入力テンプレートの過剰規定 | 軽微な注意: key value を「1〜2個」と明示することで、過剰な記述化を防ぐ。 |
| #6 | 対称化の実効差分 | **非抵触**: 変更前との実効差分は SAME・DIFFERENT 両側に均等に 3 行追加。 |
| #7 | 中間ラベルのアンカリング | 非抵触: key value の選択は具体的な変数名・返り値であり、判定方向と相関するラベルではない。 |
| #8 | 受動的記録は検証を誘発しない | 注意あり: key value を具体的な値と file:line で記述させることで、もっともらしいテキストの生成ではなく実際のコード参照を必要とする設計にしている。ただし BL-8 と同一リスクが皆無とは言えない。 |
| #9〜#11 | メタ認知・ゲート・順序 | 各々非抵触（上記 BL 照合参照） |

---

## 7. 変更規模

- 追加行数: **3 行**（テンプレート本体のみ）
- 削除行数: 0 行
- 変更行数: 0 行
- 既存の研究コア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）: **変更なし**
- Compare テンプレートの全体構造: **変更なし**（既存 Claim ブロック内への 3 行追記のみ）
