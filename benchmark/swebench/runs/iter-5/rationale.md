# Iteration 5 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: 3ケース (持続的失敗)
- 失敗原因の分析: 失敗した3ケースはいずれも EQUIVALENT ペアの誤判定。
  エージェントが複数の関数をトレースしながら「各トレースがテスト判定に
  到達する経路上にあるか」を明示的に確認しないまま EQUIVALENT を宣言する
  「不完全な推論チェーン」パターンが主因と判断した。

## 改善仮説

compare モードの Step 4 (Interprocedural tracing) テーブルに
"Relevance to test" 列を追加することで、エージェントが各関数トレースの
記入時点で「このトレースは relevant test の判定に接続しているか」を
自問する構造を強制できる。これにより、トレースの接続性確認が不十分なまま
EQUIVALENT を宣言する誤判定 (confident-but-wrong) の頻度が減少し、
compare モードの全体正答率が向上すると仮説を立てた。

本改善は Exploration Framework カテゴリ F (原論文の未活用アイデアを導入する)
のサブタイプ 2 に該当する。原論文の Fault Localization テンプレートの
Phase 2 は per-method の RELEVANT 列を持ち、localize モードと同等の
接続性チェックを diagnose モードで実現している。同じ構造を compare モードの
Step 4 に持ち込む。

## 変更内容

Step 4 (Interprocedural tracing) のテーブルヘッダーとサンプル行に
"Relevance to test" 列を追加した。変更は2行のみ（ヘッダー行とサンプル行）。

変更前:
```
| Function/Method | File:Line | Behavior (VERIFIED) |
|-----------------|-----------|---------------------|
| [name] | [file:N] | [actual behavior after reading the definition] |
```

変更後:
```
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| [name] | [file:N] | [actual behavior after reading the definition] | [which test(s) and why this function is on the relevant path] |
```

新規ステップ・新規セクションの追加なし。既存テーブルの列数変更のみ。

## 期待効果

1. **不完全な推論チェーンの抑制**: Relevance 列への記入がトレースと
   テスト判定の接続確認を強制する。Guardrail #5 "Do not trust incomplete
   chains" の実行を構造的に後押しする。

2. **微細な差異の棄却防止**: Guardrail #4 "Do not dismiss subtle differences"
   の対象パターンに対して、テーブル記入の時点で差異が relevant test の
   経路上にあるかを問い直す機会が生まれる。

3. **回帰リスクが低い**: 変更範囲は Step 4 テーブルの列追加のみ。
   既存ステップの構造・順序・内容に影響しないため、正答済みのケースへの
   悪影響は限定的と考える。
