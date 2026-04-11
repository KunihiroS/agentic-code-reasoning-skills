# Iteration 41 — 改善案提案（再提案）

## 1. 選択した Exploration Framework カテゴリとその理由

**カテゴリ B: 情報の取得方法を改善する**
> 「何を探すかではなく、どう探すか・何を確認してから判断するかを改善する」

### 理由

前回提案（カテゴリ F、Step 5 への verdict-conditioned な 2 bullet 追加）は以下の理由で却下された：
- カテゴリ F は iter-38/39/40 ですでに複数回試行済みであり、今回は iter-39 の immediate caller 方向と実効的に重なる
- Step 5 への verdict 別 bullet 追加は、既存の generic refutation 義務との差分で見ると主に NOT_EQ 側の追加探索義務として作用する（BL-2/BL-6/BL-12 系）
- EQUIV 側 bullet の「direct assert」という観測フレームが BL-5/BL-11/BL-16 系の回帰リスクを持つ

監査役の示唆した代替方向：**「変更関数で差分を見つけたら、次に読むのは広い caller/wrapper 探索ではなく、すでに relevant と判定した test path 上の nearest consumer とする」**（カテゴリ B、探索優先順位の1文改善）。

カテゴリ B の既試行との差分：
- **iter-37（B）**: テスト assertion から 1 段逆方向に遡る（backward: test→data value→production code）
- **iter-39（F）**: immediate caller を一般的に読む（generic caller、test path への anchoring なし）
- **今回（B）**: 変更関数の差分発見後、すでにトレース済みの relevant test call path 上の nearest consumer を読む（forward: changed function→consumer on test path）

iter-37 は backward 方向でスコアを改善したが、「コード差分発見 → caller 吸収未確認のまま NOT_EQ」という EQUIV 偽陰性は残った。本提案は forward 方向を補完し、checklist 既存行の精度を高める。

---

## 2. 改善仮説（1つ）

**「Compare checklist の既存行『When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact』を精緻化し、差分発見後のトレース方向を明示することで、EQUIV 偽陰性（コード差分発見 → 吸収確認省略 → NOT_EQ 結論）を減らせる」**

現在の失敗パターン（15368, 13821）：

1. エージェントが変更関数 X のコード差分を発見する（Step 3/4）
2. 「X が異なる値を返す」という Claim を書く
3. Comparison: DIFFERENT を記録する
4. COUNTEREXAMPLE セクションで NOT_EQ を結論する

根本問題：既存の checklist 行「When a semantic difference is found, trace at least one relevant test through the differing path」が曖昧であり、エージェントはこれを「変更関数 X を読んだ（=差分を見た）」時点で満たしたと解釈できる。差分が X の呼び出し元（テストのコールパス上の nearest consumer）で正規化・吸収されるかを確認せずにトレースを終える。

改善仮説：既存行を「差分発見後は、すでにトレース済みの relevant test call path 上の nearest consumer を読み、差分が伝播するか吸収されるかを記録してから Claim を確定せよ」という方向を明示した形に書き換えることで、エージェントが変更関数で止まらず確実に消費関数まで読むようになり、吸収されているケースで EQUIV に正しく判定できるようになる。

iter-37（Category B、backward 方向）との補完関係：iter-37 はテスト assertion から 1 段逆方向に遡る backward tracing を追加し、スコアを改善した。しかし「コード差分 → 変更関数で止まる → NOT_EQ」というショートカットには作用しなかった。本提案は変更関数から forward に nearest consumer まで読むことを要求することでそのショートカットを塞ぐ。両者は方向が異なり、互いに補完的である。

iter-39（Category F、immediate caller）との差分：iter-39 は一般的な immediate caller を読む義務を追加したが、test path への anchoring がなく広範な caller 探索を促す可能性があった（BL-17 の scope expansion リスク）。本提案は **すでに relevant と判定した test call path 上の** nearest consumer を読むことに限定しており、探索範囲の拡張を避けながらターゲットを絞る。また verdict-conditioned ではなく（「before asserting NOT_EQ」という形式を持たない）、BL-2/BL-14 型の立証責任引き上げにならない。

---

## 3. SKILL.md の変更内容

### 変更箇所

`### Compare checklist` の既存行「When a semantic difference is found...」を、トレース方向を明示した形に書き換える（置換 1 行）。

### 変更前（現状）

```
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- For each relevant test, read the test to identify the data value it reads or compares to determine pass/fail; trace back one step to where that value is produced and verify whether the change affects it before writing a Claim
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

### 変更後（既存行の置換）

```
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- For each relevant test, read the test to identify the data value it reads or compares to determine pass/fail; trace back one step to where that value is produced and verify whether the change affects it before writing a Claim
- Trace each test through both changes separately before comparing
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), do not stop tracing at that function: read the function on the already-traced relevant test call path that consumes the changed output, and record whether it propagates or absorbs the difference before assigning the Claim outcome.
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

### 変更規模

- 置換: 1 行（既存行を書き直す）
- 追加・削除行数: 実質 ±0（1 行 → 1 行）
- 新セクション追加: なし
- 目安（20 行以内）: クリア

---

## 4. EQUIV / NOT_EQ 正答率への影響予測

### EQUIV 正答率（現 SKILL.md ベースで約 80%）

| ケース | 現状 | 予測 | 根拠 |
|--------|------|------|------|
| 15368 (EQUIV → NOT_EQ) | 誤答 | 改善可能 | 変更関数で差分発見後、nearest consumer（test call path 上）を読む義務が明示され、吸収を発見すれば Claim を PASS に修正できる |
| 13821 (EQUIV → NOT_EQ) | 誤答 | 改善可能 | 同上 |
| 他 8 件 (正答 EQUIV) | 正答 | 維持 | nearest consumer を読んでも差分伝播が確認される → 既存の正答を上書きしない |

**期待: +1〜+2（80% → 85〜90%）**

### NOT_EQ 正答率（現 SKILL.md ベースで約 90%）

| ケース | 現状 | 予測 | 根拠 |
|--------|------|------|------|
| 11433 (NOT_EQ → UNKNOWN) | 誤答 | 変化なし | ターン枯渇が主因。nearest consumer を読む追加ステップはあるが、真の NOT_EQ では consumer が差分を伝播させるためすぐに確認でき、ターン消費は最小 |
| 他 8 件 (正答 NOT_EQ) | 正答 | 維持 | 真の NOT_EQ では nearest consumer の読みは「差分伝播を確認した」として Claim を補強し、結論に影響しない |

**期待: 維持（90%）**

### 総合期待

| 現 SKILL.md ベース | 期待スコア |
|-------------------|-----------|
| 85%（EQUIV 8/10, NOT_EQ 9/10） | 88〜90%（EQUIV が +1〜2 改善） |

---

## 5. failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL # | 内容 | 本提案との関係 |
|------|------|--------------|
| BL-2 | NOT_EQ 証拠閾値の厳格化 | **非抵触**: verdict-conditioned ではない（「before asserting NOT_EQ」形式ではない）。差分発見時に nearest consumer を読む行動は EQUIV ケースでは吸収確認、NOT_EQ ケースでは伝播確認になる。立証責任を非対称に引き上げない |
| BL-6 | 対称化（既存差分が片側に作用） | **非抵触**: 既存行の書き換えであり追加ではない。変更前との差分は「nearest consumer on test path を読む」という方向指定で、これは差分発見時に常に発火する（verdict-conditioned ではない） |
| BL-8 | 受動的記録フィールド追加 | **非抵触**: フィールド追加なし。読む行動（consumer 関数を開く）を直接要求する |
| BL-9 | メタ認知的自己チェック | **非抵触**: 自己評価ではなく、具体的なファイル読取行動を指示する |
| BL-10 | 弁別力のないゲート | **非抵触**: ゲート（YES/NO 分岐）ではなく探索方向の指定。失敗モード（差分発見後 → 吸収未確認）と直交していない |
| BL-12 | 固定順序化（Entry フィールド） | **非抵触**: フィールド追加なし。トレースの方向を「差分発見後は consumer を読め」と指定するのみ |
| BL-14 | アドバイザリな非対称指示 | **非抵触**: 「DIFFERENT と主張する場合にのみ」という非対称条件なし。差分発見時（EQUIV/NOT_EQ どちらの結論でも発火）に consumer を読む |
| BL-17 | caller/wrapper/helper への scope 拡張 | **非抵触**: 「already-traced relevant test call path 上の」consumer に限定し、relevant test 集合を拡張しない |
| BL-18 | 条件付き特例探索 | **非抵触**: 特例（削除テスト等の特定症状）ではなく、差分発見時に常時適用される主ループの一部 |
| BL-19 | EDGE CASES の Claim 内統合 | **無関係** |

### 共通原則照合

| 原則 | 本提案の評価 |
|------|------------|
| #1 判定の非対称操作 | **対称**: 差分発見時に constant に発火。EQUIV では吸収確認、NOT_EQ では伝播確認として均等に作用 ✓ |
| #2 出力側の制約は効果なし | **探索プロセス側**: Claim 確定前の読取行動を指示（出力テンプレートの禁止/要求ではない）✓ |
| #3 探索量の削減は常に有害 | **探索増加**: nearest consumer を読む 1 ステップを追加 ✓ |
| #4 同方向の変更は同結果 | **異なる方向**: iter-37 は backward（test→value→code）、iter-39 は generic caller（F）、本提案は forward on test path（B, 既存行書換）✓ |
| #5 入力テンプレートの過剰規定 | **視野拡張**: 「nearest consumer on test path を読め」は消費側への視野拡張。観測点を固定ラベルに絞らない ✓ |
| #6 既存制約との差分で評価 | **既存行の精緻化**: 追加ではなく置換（書き換え）。差分は「how to trace」の方向明示のみ ✓ |
| #7 分析前のラベル生成 | **Claim 確定前（分析中）への適用**: アンカリングバイアスのリスクなし。ラベルを事前に付けるのではなく、証拠を集めてから Claim を書く ✓ |
| #8 受動的記録フィールド | **能動的探索**: consumer 関数を実際に読む行動を誘発 ✓ |
| #9 メタ認知的自己チェック | **自己評価なし**: 外部的に検証可能な行動（特定関数を読む）を要求 ✓ |
| #10 弁別力のないゲート | **弁別力あり**: consumer が差分を伝播するか吸収するかは、EQUIV 偽陰性（吸収）と真 NOT_EQ（伝播）を実際に弁別する条件 ✓ |
| #12 アドバイザリな非対称指示 | **非対称条件なし**: 「このときだけ」という verdict-specific 発火条件を持たない ✓ |
| #14 条件付き特例探索 | **主ループの改善**: 差分発見時に常時適用される中心ループの一部 ✓ |

---

## 6. 変更規模

- 置換行数: **1 行**（既存行「When a semantic difference is found...」→ 新行）
- 追加・削除行数: **0**（1 行 to 1 行）
- 新セクション追加: **なし**
- 変更対象: `### Compare checklist` の 6 番目の bullet
- 目安（20 行以内）: **クリア**

---

## 付記: 現 SKILL.md ベースの失敗状況

本提案は **現 SKILL.md（iter-35 相当）** を基準とする。iter-40 の EDGE CASES 削除変更（BL-19）は既にロールバック済み。

| 現 SKILL.md の失敗ケース | パターン | 本提案の直接的作用 |
|--------------------------|---------|-------------------|
| django__django-15368 | EQUIV → NOT_EQ | 変更関数で差分発見後、nearest consumer（test path 上）を読む → 吸収確認 → Claim PASS に修正可能 |
| django__django-13821 | EQUIV → NOT_EQ | 同上 |
| django__django-11433 | NOT_EQ → UNKNOWN | 直接的作用は限定的（ターン枯渇が主因）。nearest consumer 確認が伝播を迅速に確認できれば多少の改善余地あり |

