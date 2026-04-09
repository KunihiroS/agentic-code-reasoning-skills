# iter-118 Proposal

## Exploration Framework カテゴリ: E

### カテゴリ選択理由

カテゴリ E「表現・フォーマットを改善する（曖昧文言の具体化、簡潔化、例示）」を強制指定に従い採用する。

今回のフォーカスドメインは `equiv`（2つの実装が同一の振る舞いを持つと判定する精度の向上）である。
compare モードの `NO COUNTEREXAMPLE EXISTS` セクション（SKILL.md L196-202）を精査すると、
最終行の `[brief reason]` という placeholder が極めて抽象的であり、equiv 判定時に
「なぜ反証が存在しないのか」を論述する際の観点が何ら示されていない。
この曖昧さが、equiv 判定の結論を「証拠が見当たらなかった」という消極的な記述に留めさせ、
積極的な根拠（変更された振る舞いがどのテスト観測点にも届かない理由）の記述を誘発しない。
カテゴリ E のメカニズムとしては「曖昧な placeholder を具体化し例示を補う」を選択する。


## 改善仮説

equiv 判定の最終論拠フィールド（NO COUNTEREXAMPLE EXISTS の conclusion 行）において、
`[brief reason]` という抽象 placeholder を「変更差分が到達しうる観測点の非存在を述べよ」
という方向に具体化することで、equiv 判定時の論述が「証拠を探したが見つからなかった」という
消極的な不在証明から「変更がテストの観測境界に届かないことを積極的に論じた」記述へと誘導され、
equiv の誤判定（根拠の薄い equiv 結論）を削減できる。


## 変更内容

### 変更対象

SKILL.md、compare テンプレートの `NO COUNTEREXAMPLE EXISTS` セクション。

### 変更前（L202）

```
  Conclusion: no counterexample exists because [brief reason]
```

### 変更後（L202）

```
  Conclusion: no counterexample exists because [state why the behavioral difference, if any, does not reach any test observation point — e.g., the differing path is unreachable, the output is unused, or no test assertion captures the changed value]
```

### diff イメージ

```
-  Conclusion: no counterexample exists because [brief reason]
+  Conclusion: no counterexample exists because [state why the behavioral difference, if any, does not reach any test observation point — e.g., the differing path is unreachable, the output is unused, or no test assertion captures the changed value]
```

変更規模: 1行（既存行の文言精緻化のみ。新規ステップ・新規フィールド・新規セクション追加なし）


## 期待効果

### 改善される失敗パターン

equiv ドメインで観察される典型的な失敗パターンは「反証の探索を行ったが見つからなかった」
という消極的な記述だけで equiv 結論を正当化するケースである。
変更後のテンプレートは、equiv 結論を書く際に「差分がテスト観測点に届かない理由」を
3種の具体的な観点（到達不能パス / 未使用出力 / アサーション非捕捉）で考えさせる。
これにより、根拠の薄い equiv 判定が減り、equiv の精度が向上する。

### NOT_EQ への影響

examples は「到達しない場合」の例示であり、「到達する場合に equiv とせよ」という
非対称な立証要求ではない。到達性の判断は双方向に使われるため、NOT_EQ の判断を阻害しない。


## failed-approaches.md との照合

| 原則番号 | 内容要約 | 抵触確認 |
|----------|----------|----------|
| #1 | 判定の非対称操作は失敗する | 抵触なし。例示は到達性の判断を促すものであり、equiv への誘導ではない。 |
| #2 | 出力側の制約は効果がない | 抵触なし。出力制約ではなく推論の観点を具体化するもの。 |
| #3 | 探索量の削減は常に有害 | 抵触なし。探索量を減らす変更ではない。 |
| #4 | 同じ方向の変更は表現を変えても同じ結果 | 抵触なし。今回は「equiv を出やすくする」ではなく「論拠の質を高める」方向。 |
| #5 | 入力テンプレートの過剰規定は探索視野を狭める | 抵触なし。1フィールドの placeholder 精緻化であり、収集情報の種類を制限しない。 |
| #12 | アドバイザリな非対称指示も立証責任の引き上げになる | 要注意。ただし本変更は「equiv 結論時のみに付加要求」ではなく、既存の conclusion 行の説明精緻化であり、NOT_EQ 結論時のテンプレートには触れない。差分は中立的な表現精緻化にとどまる。 |
| #16 | ネガティブプロンプトによる局所禁止は過剰適応を招く | 抵触なし。禁止事項を追加していない。 |
| #20 | 既存表現の「より厳格」な書き換えは立証責任の引き上げになる | 要注意。`[brief reason]` → 長い instruction への置き換えは表現の強化である。ただし、指示の方向は「なぜ差分が観測点に届かないかを述べよ」という証拠ベースの論拠強化であり、「equiv と主張するな」という禁止ではない。また placeholder を具体化するだけであり、既存の構造・手順・フィールド数は変えない。 |

照合結果: 既知の失敗原則への抵触なし


## 変更規模の宣言

- 変更行数: 1行（変更後の行が既存の1行を置き換える）
- 削除行数: 0行（置き換えのため削除は変更行数に含まない）
- ハードリミット（5行以内）: 遵守
