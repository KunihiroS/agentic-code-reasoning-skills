# Iteration 25 — 変更理由

## 前イテレーションの分析

- 前回スコア: 65%（13/20）
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-14787, django__django-11433, django__django-14122, django__django-12663
- 失敗原因の分析:
  - EQUIV → NOT_EQUIVALENT 誤判定（15368・13821）: エージェントがコードレベルの差異を発見した時点で、assertion に到達する値が A・B で同一かどうかを確認しないまま DIFFERENT と結論した。
  - EQUIV → UNKNOWN（15382）: ターン上限に達したが、その根本には assertion 到達値の確認なしに広い探索を行った傾向がある。
  - NOT_EQUIVALENT → UNKNOWN（14787・11433・14122・12663）: テスト対象の assertion を決定する具体的な値の追跡が不十分なまま探索が広がり、判定不能に陥った。

## 改善仮説

Compare モードの `ANALYSIS OF TEST BEHAVIOR` において、各 relevant test の `Claim C[N].1 / C[N].2` を書く前に、テストの assertion を決定する key value（1〜2個）について Change A・Change B 両方で「生成 → 変更 → assertion での値」を対称的にトレースさせる。これにより、エージェントは「コードレベルの差異の発見」ではなく「assertion 到達時点での具体的な値の一致/不一致」を根拠として Claim を書くようになり、EQUIV 偽陽性（コード差異があっても assertion 値は同じ → SAME を見落とす）と NOT_EQ の両方に対して推論の正確度が上がる。

`explain` モードの DATA FLOW ANALYSIS テンプレートが「Created at / Modified at / Used at」という3点で変数の意味論的状態を追跡する手法を、compare の A・B 両変更に等しく適用することで、SAME/DIFFERENT どちらの結論にも同じ粒度で作用する共通の中間表現を生成させる。これは LLM のコード解析精度を上げる確立された手法（LLMDFA, arXiv:2402.10754）に基づく。

## 変更内容

Compare certificate template の `ANALYSIS OF TEST BEHAVIOR` セクション内、`For each relevant test:` ブロックに `Key value` フィールドを3行追加した。

- `Test: [name]` の直後に、assertion を決定する key value（1〜2個の変数または返り値）について、A・B それぞれで「created [file:line] → last modified [file:line or NONE] → value at assertion [file:line]: [value/state]」という形式でトレースするフィールドを追加。
- 追加: 3行（Key value ヘッダー + With A + With B）
- 削除: 0行
- 変更: 0行
- 他セクション（localize, explain, audit-improve）・ガードレール・Minimal Response Contract への変更なし。

## 期待効果

- **EQUIV 側（改善期待）**: Key value のトレースにより、コードレベルの差異があっても assertion に到達する値が A・B で同一であることを確認する機会が生まれる。「A では [file:line] で X が返る、B では Y が返る」という中間的差異の発見だけで DIFFERENT と結論することへの自然な抑制になる（assertion での値が同じなら SAME）。
- **NOT_EQ 側（維持）**: 真の NOT_EQ では、key value の assertion 到達時の値が A と B で異なるため、トレースが DIFFERENT 主張を自然に支持する。追加的な立証責任を課すわけではなく（SAME 主張にも同じ形式が適用されるため非対称な制約にならない）、key value 1〜2個の追加記述のみでターンコスト増加は限定的。
