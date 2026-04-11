# Iter-7 Proposal

## Exploration Framework カテゴリ: B（強制指定）

カテゴリ B は「情報の取得方法を改善する」に分類される。
今回は「探索の優先順位付けを変える」メカニズムを選択する。

理由: SKILL.md の Step 3 には `NEXT ACTION RATIONALE` フィールドがある。
このフィールドは「なぜ次のファイルを開くか」を書くものだが、
「何の具体的証拠を探しに行くか」を明示する指示が存在しない。
その結果、仮説が REFINED（未解決）のまま次ファイルへ移るとき、
どの証拠を優先的に収集すべきかが不明確になり探索がドリフトしやすい。
カテゴリ B の「どう探すかを改善する」は、このフィールドの精緻化と合致する。


## 改善仮説

NEXT ACTION RATIONALE に「探しに行く証拠の種類（仮説を確認/反証するための
具体的なシグナル）」を明示させることで、ファイル探索がその仮説に対して
必要な情報に絞り込まれ、見落としと冗長な探索の両方が減る。


## SKILL.md のどこをどう変えるか

### 変更対象箇所

SKILL.md Step 3 の HYPOTHESIS UPDATE ブロック内にある
`NEXT ACTION RATIONALE` の行（現行 93 行目付近）

### 変更前（SKILL.md 引用）

```
NEXT ACTION RATIONALE: [why the next file or step is justified]
```

### 変更後（提案）

```
NEXT ACTION RATIONALE: [why the next file or step is justified — and what specific signal (presence/absence of a call, a value, a branch) you are looking for to confirm or refute the active hypothesis]
```

### 変更規模の宣言

- 変更行数: 1 行（既存行への文言追加）
- 新規ステップ・新規フィールド・新規セクション: なし
- 削除行: 0 行
- 合計変更行数: 1 行（hard limit 5 行以内 を満たす）


## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. 探索ドリフト（overall 品質低下の主因）
   - 仮説が REFINED のまま次ファイルへ移る際、何を見るべきかが曖昧だと
     関連性の低いコードを読み込んで文脈が膨張する。
   - 探しに行くシグナルを明示することで、読むべき箇所が絞り込まれる。

2. Guardrail #4「微妙な差異の見落とし」（compare モードの overall 正答率に影響）
   - 差異がありそうなコードパスへの遷移時に、どのシグナル（呼び出し経路の
     有無・分岐条件の値・戻り値の型）を確認すべきかを事前に宣言させることで、
     読んだ後に「確認した証拠」と「確認すべきだったが見なかった証拠」が
     区別しやすくなる。

3. 不完全な推論チェーン（docs/design.md §4.3 で言及の失敗パターン）
   - 次の探索で何を確認するかを先に宣言することが、
     後続の OBSERVATIONS と HYPOTHESIS UPDATE の網羅性チェックになる。


## failed-approaches.md の汎用原則との照合結果

現在 failed-approaches.md は空（ベンチマーク刷新後リセット済み）であり、
照合すべきブラックリスト原則は存在しない。

抵触なし。


## 変更規模の宣言（再掲）

- 追加・変更: 1 行（既存行の文言追加・精緻化）
- 削除: 0 行
- hard limit（5 行）に対して 1 行。制限を満たす。
