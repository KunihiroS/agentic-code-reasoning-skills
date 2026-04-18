# Iteration 29 — Overfitting 監査

## 判定: FAIL
## 合計スコア: 12/18

| # | 項目 | スコア | 根拠 |
|---|------|--------|------|
| R1 | 汎化性 | 3 | diff/rationale にはベンチマーク対象リポジトリの固有識別子（リポジトリ名、ファイルパス、関数名、クラス名、テスト名、テスト ID、実装コード引用）は含まれていない。変更内容も一般的な compare 推論手順の具体化であり、特定ケース専用の条件分岐ではない。 |
| R2 | 研究コアの踏襲 | 2 | README.md・docs/design.md・原論文はいずれも、明示的 premises、per-test tracing、interprocedural tracing、mandatory refutation をコアとしている。本変更は「差分を見つけても assertion まで結び付ける／下流吸収を示す」という形で、不完全な reasoning chain を抑える方向では整合的。ただし論文・設計文書のコアは「テスト結果までの証拠付き追跡」であり、「specific test assertion」への固定は元のコアより狭い。 |
| R3 | 推論プロセスの改善 | 2 | 変更は結論ラベルを直接指示せず、「semantic difference 発見後に earliest divergence を局所化し、assertion への接続または downstream neutralization を示す」という推論手順を追加しているため、形式上はプロセス改善である。ただし no-impact 判断を単一の観測境界へ強くアンカーしており、探索経路の自由度を下げる懸念がある。 |
| R4 | 反証可能性の維持 | 2 | 「no impact」と言う前に assertion まで結び付ける／neutralization を示す、という要求は、差分軽視への反証圧力を強める点でプラス。ただし反証の幅を広げるというより、反証の成立形式を特定の観測境界へ寄せており、反証可能性の強化としては限定的。 |
| R5 | 複雑性の抑制 | 2 | 1 行置換で変更規模は小さい。一方で要求内容は「earliest divergence」「specific test assertion」「downstream neutralization」という複数概念を一度に追加しており、運用上の認知負荷はやや増す。改善に見合う範囲ではあるが、明確化一辺倒とは言いにくい。 |
| R6 | 回帰リスク | 1 | failed-approaches.md にある「既存の判定基準を、特定の観測境界だけに過度に還元しすぎない」「探索の自由度を削りすぎない」という失敗原則にかなり近い。今回の文言は、意味差分の評価を『specific test assertion へ局所化できるか』に強く寄せており、テスト結果同値性の判断に有効でも assertion 単位へ自然に落ちない証拠や、より広い call chain 上の差分評価を過小化する回帰リスクが高い。 |

## 総合コメント

この変更は、論文と既存 SKILL.md が重視する「 subtle difference dismissal を防ぐ」「テスト観測まで追跡する」という方向には沿っており、overfitting の典型であるベンチマーク固有識別子も含まれていない。その点で R1 は問題ない。

しかし failed-approaches.md のブラックリストとの整合で見ると、今回の改善は危うい。特に「差分の重要度判断を特定の観測境界に過度に還元しないこと」「探索の自由度を削りすぎないこと」という既知の失敗原則に対し、本変更は no-impact 判定を『earliest divergence → specific test assertion』という狭い経路に半固定している。これは不完全分析の防止には見えても、実際には比較判断を特定の観測形式へ寄せ、他の有力な反証経路や同値化の根拠を拾いにくくする可能性がある。

したがって、総合的には「研究コアからの逸脱ではないが、既知の失敗方向に近く、回帰リスクが高い」変更と判断する。合計点は 12/18 だが、R6 が 1 のため不合格。