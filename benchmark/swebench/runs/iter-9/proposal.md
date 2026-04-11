# Iteration 9 — Proposal

## Exploration Framework カテゴリ

カテゴリ D: メタ認知・自己チェックを強化する（強制指定）

### カテゴリ D 内でのメカニズム選択理由

カテゴリ D には以下の 3 つのメカニズムが定義されている:

1. 推論の途中で自分の思い込みを疑うチェックポイントを追加
2. 結論に至った推論チェーンの弱い環を特定させる
3. 確信度と根拠の対応を明示させる

今回は 2「弱い環の特定」を選択する。理由は以下の通り:

- SKILL.md の Step 5.5（Pre-conclusion self-check）は現状、証拠の「充足性」確認
  （file:line が存在するか、VERIFIED か、実際に検索したか）に特化している。
- しかし overall 推論品質における典型的な失敗パターンは「証拠はあるが最も
  不確かなリンクに気づかずに HIGH confidence 結論を出す」という形態をとる。
  これは docs/design.md の「Incomplete reasoning chains」(§4.3 Error Analysis)
  に対応する。
- 現在の 4 チェック項目はすべて YES/NO の二値判定であり、
  「どのクレームが最も弱いか」を能動的に問うチェックは存在しない。
- メカニズム 1（思い込み疑念）は Step 3 の HYPOTHESIS UPDATE に既に内包されており、
  メカニズム 3（確信度と根拠の対応）は Step 6 の CONFIDENCE 宣言でカバーされている。
  未実装の空白はメカニズム 2 のみである。

---

## 改善仮説（1 つ）

Step 5.5 の Pre-conclusion self-check において、推論チェーン中で
「最も根拠が薄いクレームはどれか」を明示させる問いを加えることで、
エージェントが証拠不十分なまま高確信度の結論を出す失敗パターンを
抑制できる。

---

## SKILL.md の変更内容

### 変更対象

SKILL.md の Step 5.5 の既存チェックリスト末尾（4 項目目の直後、
Step 6 見出し直前）に、既存行の精緻化として 1 行を追加する。

### 変更前（現在の Step 5.5 末尾）

```
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
```

### 変更後

```
- [ ] The conclusion I am about to write asserts nothing beyond what the traced evidence supports.
- [ ] Identified the weakest link in the reasoning chain (the claim with the lowest evidence density) and verified it is sufficient to support the confidence level I will assign in Step 6.
```

### 変更規模の宣言

追加行数: 1 行
削除行数: 0 行
合計変更規模: 1 行（hard limit の 5 行以内に適合）

### 変更行の正確な文言

追加する 1 行:
```
- [ ] Identified the weakest link in the reasoning chain (the claim with the lowest evidence density) and verified it is sufficient to support the confidence level I will assign in Step 6.
```

---

## 期待効果

### 減少が期待される失敗パターン

1. **Incomplete reasoning chains（不完全な推論チェーンによる過信）**
   - 現状: エージェントは 4 つの YES/NO チェックをパスすると Step 6 に進む。
     証拠の「有無」は確認するが「最も弱い環」に自覚的に注目することがない。
   - 改善後: 結論を書く前に、自分のチェーンのうち最も薄い根拠を持つクレームを
     特定し、それが宣言する CONFIDENCE（HIGH/MEDIUM/LOW）を支えるに
     足りるかを明示的に問い直す。これにより HIGH confidence のまま
     weak link を見落とす誤りが減る。

2. **Subtle difference dismissal（微妙な差異の過小評価）**
   - compare モードで「差異はあるが影響なし」と誤って判定する場合、
     その「影響なし」判断が最も証拠の薄いクレームになることが多い。
     弱い環チェックはこの判断を浮かび上がらせる。

3. **overall 方向（全体推論品質）への寄与**
   - チェックは結論直前に置かれるため、診断・説明・監査モードにも同様に適用され、
     モードに依存しない汎用的な品質底上げになる。

---

## failed-approaches.md の汎用原則との照合

### 原則 1: 探索シグナルを事前固定しすぎる変更は避ける

本変更は探索フェーズ（Step 3）ではなく、結論直前の Step 5.5 に対する変更である。
探索の「何を探すか」「どう探すか」を制約するものではなく、
すでに集めた証拠を振り返るメタ認知チェックの追加である。
=> 抵触しない

### 原則 2: ドリフト抑制が探索の自由度を削りすぎてはならない

本変更は探索の自由度そのものに触れない。
Step 5.5 への追加チェックは探索を誘導するのではなく、
探索済みの証拠に対するメタ評価を強制するものである。
仮にエージェントが「弱い環はない」と判断した場合でも
探索を打ち切る・再開するなどの行動変容を強制する記述はない。
=> 抵触しない

---

## 変更規模の宣言

- 追加行: 1 行
- 変更行: 0 行
- 削除行: 0 行
- 合計: 1 行（hard limit 5 行以内、適合）
- 新規ステップ・新規フィールド・新規セクションの追加: なし
  （既存の Step 5.5 チェックリストへの項目追加であり、
   既存行への精緻化の範囲内と判断する）
