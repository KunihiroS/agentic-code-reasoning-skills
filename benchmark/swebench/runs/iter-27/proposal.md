# Iteration 27 — 改善案提案

## 選択した Exploration Framework カテゴリ

**カテゴリ A: 推論の順序・構造を変える**
サブ方向: **「結論から逆算して必要な証拠を特定する（逆方向推論）」**

### 選択理由

iter-1〜26 の試行履歴と共通原則を照合した結果、以下の状況を確認した。

| カテゴリ | 主な試行 | 評価 |
|---------|---------|------|
| A（順序・構造） | BL-4（早期打ち切り）、BL-12（テスト先読み固定順序） | **逆方向推論は未試行** |
| B（情報取得） | BL-5, BL-10, BL-11, BL-12 | 多数試行済み |
| C（比較の枠組み） | BL-1, BL-7, BL-13 | 多数試行済み |
| D（メタ認知） | BL-8, BL-9 | 構造的失敗パターンあり |
| E（表現・形式） | BL-6, BL-11 | 既存文言の変形にとどまる |
| F（論文未活用） | BL-8（RELEVANT 列）など | 一部試行済み |

カテゴリ A の「逆方向推論」は試行されていない。BL-4（探索の早期打ち切り）・BL-12（探索の開始順序の固定）はいずれも「探索の制限」であり、「結論から逆算して証拠を特定する」という逆方向推論とは本質的に異なる。

---

## 改善仮説（1つ）

**仮説**: Compare モードの「DIFFERENT outcome」主張において、順方向（コード差分 → テスト結果）のトレースのみが行われており、「テストのアサーション条件から逆算してコード差分が因果連鎖に存在するか」を確認する検証が欠如している。この検証をチェックリストに追加することで、EQUIV 偽陽性（コード差分を発見したが、そのアサーション因果連鎖への到達を確認しないまま NOT_EQ と結論するパターン）を削減できる。

背景・根拠:
- 持続的失敗 3 件（15368, 15382, 13821）はいずれも「コード差分またはテスト差分を発見 → アサーション因果連鎖の到達確認なしに NOT_EQ を結論」という同一パターンを示す。
- 15368: テスト削除を「テスト結果が変わる」と解釈（アサーション連鎖の確認なし）。
- 15382: ループ+例外のトレースが誤り（iter-5 の反事実チェックを経ても修正されず）。根本原因は forward trace の誤りを backward 方向から検証する手段がないこと。
- 13821: D2 の call path 判定を過剰適用（テストの assertion が実際に差分の影響を受けるかを確認していない）。
- 現行 Compare チェックリストには「差異があると結論する前にテストをトレースせよ（EQUIV 方向）」はある（5項目め）が、「差異が存在すると判断した場合、アサーション連鎖への到達を逆算確認せよ（NOT_EQ 方向）」の対称的な指示が欠如している。
- 逆方向推論は「入力テンプレートの過剰規定」でも「受動的記録フィールドの追加」でもなく、既存の証拠収集ステップに新たな推論方向を加えるもの。

---

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の `### Compare checklist` に1項目追加。

### 現在の Compare checklist（末尾3項目）

```
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

### 変更後（追加1項目 — `★` は追加箇所）

```
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- ★ When claiming a test outcome DIFFERS: verify backward — from the test's assertion condition through the causal chain to the code difference — that the divergence between A and B reaches the assertion. Do not conclude DIFFERENT solely because a difference exists somewhere in the call path.
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

### 変更規模

- 追加: 2行（項目1行 + 補足文1行）
- 削除: 0行
- 合計 diff: +2行（20行以内の目安に対し余裕あり）

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV 正答率（現状 70%、7/10）

- **予測**: +10〜20pp（7→8〜10）
- 根拠:
  - 15382（ループ+例外トレース誤り）: backward 方向から「assertion が確認する値に、コード差分が到達しているか」を検証させることで、forward trace の誤りが露見しやすくなる。iter-5 の counterfactual rule が「順方向トレースの反証」を要求したのに対し、本提案は「アサーションからの逆算確認」であり、異なるメカニズム。
  - 13821（pass-to-pass 過剰スコープ）: assertion 条件から逆算することで、D2 の call path 該当性ではなく「assertion が実際に差分の影響を受けるか」を問う。
  - 15368（テスト削除）: 逆算すると「削除されたテストにはアサーション条件が存在しない」→ 因果連鎖の起点がない → 生産コードの比較対象外 という推論経路が開ける（BL-1 と異なり、定義を追加するのではなく推論方向の変化から導く）。

### NOT_EQ 正答率（現状 100%、10/10）

- **予測**: 0〜-5pp（10→9〜10）
- 根拠:
  - 現在正答している 10 件の NOT_EQ ケースでは、コード差分はアサーション因果連鎖に実際に到達している。backward 検証を行っても「到達する」という結論は変わらず、NOT_EQ 主張を強化する方向に働く。
  - リスク: 複雑なコード経路で backward trace が困難な場合、AI が確信を持てず EQUIV 方向に倒れる可能性は排除できない。しかし本変更はチェックリスト（advisory）であり、テンプレートの必須フィールドではないため、強制力は BL-2/BL-6/BL-9 より低い。
  - チェックリスト項目の文言が "Do not conclude DIFFERENT **solely because** a difference exists somewhere in the call path" であり、「差分がある上で because まで伝わっていることを確認せよ」という趣旨。正しい NOT_EQ 判定を否定するものではない。

---

## failed-approaches.md ブラックリストおよび共通原則との照合結果

### ブラックリスト照合

| BL | 内容 | 本提案との関係 |
|----|------|---------------|
| BL-1 | テスト削除を ABSENT 定義 | **非該当**。定義を追加していない。逆方向推論の帰結として推論が変わるのみ |
| BL-2 | NOT_EQ の証拠閾値・厳格化 | **要注意**。類似性あり。ただしメカニズムが異なる: BL-2 はテンプレートへの構造的要件追加、本提案はチェックリスト（advisory）への逆方向推論追加 |
| BL-3 | UNKNOWN 禁止 | 非該当 |
| BL-4 | 早期打ち切り | 非該当（探索量は増える） |
| BL-5 | P3/P4 アサーション形式 | 非該当（PREMISES には触れない） |
| BL-6 | Guardrail 4 対称化 | **要注意**。類似性あり。ただし BL-6 は「Guardrail 4 の文言を対称化」であり実効差分が NOT_EQ 側にのみ作用した。本提案は既存チェックリスト 5 項目め（EQUIV 方向）を補完する NOT_EQ 方向の追加であり、「対称化」とは文脈が異なる。 |
| BL-7 | 分析前の中間ラベル生成 | 非該当（中間ラベルを生成しない） |
| BL-8 | Relevant to 列追加 | 非該当（テーブル列の追加ではない） |
| BL-9 | Trace check 自己チェック | **要注意**。最も類似。ただし本質的相違: BL-9 は「自分はトレースしたか？」という**自己評価**；本提案は「アサーションから逆算した因果連鎖を実際にたどれ」という**能動的トレース**。BL-9 の Fail Core（自己評価精度の限界、疑念注入が NOT_EQ 遅延）は自己評価メカニズムに起因し、本提案には適用されない |
| BL-10 | Reachability ゲート（YES/NO） | 非該当（条件分岐ゲートではない） |
| BL-11 | Outcome mechanism 注釈 | 非該当（注視先を列挙するアンカリング型ではない） |
| BL-12 | Entry: フィールド・テスト先読み固定順序 | 非該当（探索の開始順序を固定しない） |
| BL-13 | Key value データフロー欄 | 非該当（記録フィールドを追加しない） |

### 共通原則照合

| 原則 | 内容 | 適合評価 |
|------|------|---------|
| #1 判定の非対称操作 | EQUIV/NOT_EQ 一方に有利な変更は失敗 | ⚠️ 一方向（NOT_EQ 方向）への追加だが、チェックリスト（advisory）且つ既存 EQUIV 方向項目の補完として設計。原則 #1 の「閾値移動」とは異なりメカニズムが逆方向推論 |
| #2 出力側制約は効果がない | 推論の質（入力・処理側）を改善すべき | ✅ 入力側（推論方向）の変更 |
| #3 探索量削減は常に有害 | 探索を減らす変更は悪化する | ✅ 逆方向のトレースを追加し探索量は増加 |
| #4 同じ方向の変更は同じ結果 | 表現を変えても方向が同じなら同結果 | ✅ backward 推論は既存の forward trace と方向が異なる |
| #5 入力テンプレート過剰規定 | 記録対象の限定は視野を狭める | ✅ 「逆算して確認せよ」は HOW を指定するが、何を記録するかは指定しない |
| #6 対称化の実効差分評価 | 既存制約との差分で効果の方向を見る | ✅ 実効差分は NOT_EQ 方向への backward check 追加。その影響は想定内で評価済み |
| #7 中間ラベル生成によるアンカリング | 分析前ラベルはショートカットを生む | ✅ 中間ラベルを生成させない |
| #8 受動的記録フィールド追加 | 記録と検証は異なる認知操作 | ✅ フィールドを追加せず、能動的推論ステップとして設計 |
| #9 メタ認知的自己チェック | 自己評価精度の限界により機能しない | ✅ 自己評価ではなく能動的 backward trace |
| #10 必要条件ゲート | 判別力のないゲートは通過されるだけ | ✅ ゲートではなく推論方向の指定 |
| #11 探索順序の固定 | 固定により探索の偏りが生じる | ✅ 全体の探索開始順序を固定せず、DIFFERENT 結論時の検証方向を追加するのみ |

---

## 変更規模

- 追加行数: 2行（チェックリスト 1 項目 + 補足文）
- 削除行数: 0行
- 変更行数の合計: 2行（目安 20行以内に対し十分に余裕あり）
- 影響範囲: Compare モードのチェックリストのみ（Core Method、他モード、Guardrails、テンプレート本体には触れない）
