# Iteration 44 — 変更理由

## 前イテレーションの分析

- 前回スコア: 65% (13/20)
- 失敗ケース:
  - EQUIV 偽陰性（NOT_EQ と誤判定）: `15368`（17 turns）, `11179`（11 turns）, `13821`（15 turns）, `15382`（20 turns）
  - NOT_EQ 偽陽性（EQUIV と誤判定）: `14787`（26 turns）
  - NOT_EQ UNKNOWN（ターン枯渇）: `11433`, `14122`
- 失敗原因の分析: iter-43 の「nearest downstream consumer」指示がエージェントを最初の消費者で止まらせた。`13821`/`11179` では downstream consumer 自体がコードレベルで A/B 異なる挙動を示すが、その差異はテストのアサーションが直接検査する観測対象（return value / assert 引数）にまで伝播しない。エージェントはコードレベルの中間差異を見つけた時点で DIFFERENT と判断し、テストのアサーション境界でその差異が吸収されるかを確認しなかった。

## 改善仮説

Compare checklist に「各 relevant test について、A と B の両方を、テストのアサーションが実際に検査する観測対象（比較している値・捕捉している例外・検証している状態）まで trace してから比較せよ。中間コードパスの差異だけで判定してはならない」という 1 文を追加することで、エージェントが trace のゴールを「コードレベルの中間差異の有無」から「テストのアサーションが検査する観測対象での差異の有無」へ移行できる。

## 変更内容

`## Compare` セクション `### Compare checklist` の末尾（「Provide a counterexample...」の直前）に 1 行追加した。

```
- For each relevant test, trace both changes through to the outcome the test's assertion checks (the value compared, the exception caught, or the state verified); compare A and B at that observable — not at intermediate code differences.
```

変更規模: +1 行（追加のみ、削除・変更なし）

## 期待効果

- **EQUIV ケース（13821, 11179）**: エージェントは中間差異を見つけても「これはアサーション観測対象か？」を問うようになる。観測対象まで追った結果、差異が fallback・デフォルト値・例外キャッチ等で吸収されることを確認できれば EQUIV と正しく判断できる。iter-43 で新規破損したこれらのケースの回帰修正を期待する。
- **NOT_EQ ケース**: 観測対象に向けて trace するという明確なゴールが探索の収束を助けるため、`11433`/`14122` のターン枯渇リスクが下がる可能性がある。`14787`（偽陽性）についても、観測対象での A/B 同一性を確認する方向に働く。
- **対称性**: 変更は EQUIV/NOT_EQ 双方向に等しく「観測対象まで trace する」義務を課すため、立証責任が一方向に偏らない。
