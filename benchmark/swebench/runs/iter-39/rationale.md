# Iteration 39 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-39 の proposal.md 作成時点での分析による）
- 失敗ケース: 詳細は scores.json 参照
- 失敗原因の分析: `compare` モードにおいて「根拠のない高確信 (high confidence without premise linkage)」が誤判定を引き起こすパターンが観察された。Step 3 で CONFIDENCE: high と宣言しても、その確信が具体的な前提番号に紐づいていないため、思い込みが CONFIDENCE 宣言に反映されないまま探索が進むケースが存在した。

## 改善仮説

仮説の CONFIDENCE を high と宣言する際に、その確信の拠り所となる前提番号を明示させることで、根拠のない高確信による誤判定を抑制できる。

## 変更内容

Step 3 (Hypothesis-driven exploration) のテンプレート内 CONFIDENCE フィールドの文言を以下のとおり精緻化した:

変更前:
```
CONFIDENCE: high / medium / low
```

変更後:
```
CONFIDENCE: high (grounded in P[N]) / medium / low
```

変更は既存の CONFIDENCE フィールドへの注釈追加 1 行のみ。新規ステップ・新規フィールド・新規セクションは追加していない。

## 期待効果

- Step 3 で高確信を宣言する際に前提参照が必須化されるため、前提として明記していない思い込みを CONFIDENCE 宣言の時点で暴露できる。
- CONFIDENCE: high と書けない（= 前提が足りない）と気づいた時点で、仮説の再検討または前提の追加が自然に促される。
- 「思い込みが破綻しても CONFIDENCE: high のまま探索を進める」という既存の soft failure を early warning に変換できる。
- `compare` モード全般で過剰確信による誤判定が減少し、equiv/not_eq の両方の正答率向上につながると期待できる。
