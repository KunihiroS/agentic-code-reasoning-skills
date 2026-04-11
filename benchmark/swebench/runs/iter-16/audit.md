# Iteration 16 — Overfitting 監査

## 判定: PASS
## 合計スコア: 19/21

| # | 項目 | スコア | 根拠 |
|---|------|--------|------|
| R1 | 汎化性 | 3 | 「Call path from test to changed code」は言語・フレームワーク非依存の汎用的要件。テストエントリポイントから変更コードへの呼び出しパスを file:line で示すという手法は、Python/Django に限らず Java、Go、C++ 等あらゆるプロジェクトに適用可能。 |
| R2 | 研究コアの踏襲 | 3 | 論文の Figure 2 および Appendix A の COUNTEREXAMPLE セクションを構造的に強化している。論文のコア要素（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）はすべて維持されており、特に手続き間トレース（interprocedural tracing）の実践を COUNTEREXAMPLE ブロック内で具体的に要求する形で強化している。 |
| R3 | 推論プロセスの改善 | 3 | NOT_EQUIVALENT を主張する際に「テストから変更コードまでの呼び出しパスを実際にトレースする」という推論ステップを追加している。結論を直接指示するのではなく、証拠収集のプロセスを構造化することで浅い反例主張を防止する。これは論文 §3 の「structured format naturally encourages interprocedural reasoning」の精神に合致。 |
| R4 | 反証可能性の維持 | 3 | COUNTEREXAMPLE ブロックの証明要件を強化しており、反証プロセスを弱めるどころか、反例の根拠をより厳密にしている。NOT_EQUIVALENT の主張に対して呼び出しパスの具体的証拠を要求することで、根拠のない反例主張のハードルを上げている。NO COUNTEREXAMPLE EXISTS ブロック（EQUIVALENT 判断側）は変更なし。 |
| R5 | 複雑性の抑制 | 3 | 追加は 1 行のみ。既存の COUNTEREXAMPLE ブロック構造に自然に統合されており、新しいセクションや条件分岐は導入されていない。既存の compare checklist「Trace each test through both changes separately before comparing」と方向性が一致しており、概念的な負荷増加も最小限。 |
| R6 | 回帰リスク | 2 | 影響範囲は compare モードの COUNTEREXAMPLE ブロック（NOT_EQUIVALENT 主張時）に限定されており、EQUIVALENT 判断パス・他モード（localize, explain, audit-improve）には影響しない。ただし、Call path の引用義務が NOT_EQUIVALENT の正当な主張を過度に困難にし、本来 NOT_EQUIVALENT であるケースを EQUIVALENT と誤判定させる軽微なリスクがある（rationale でも 14787 への影響は不確実と認めている）。改善の見込みが上回ると判断。 |
| R7 | ケース非依存性 | 2 | 変更自体はいかなる特定ケースも参照・暗示していない汎用的な構造改善である。ただし、rationale において 15368・15382・13821・14373 等の具体的ケース ID と失敗パターン（「浅い反例」問題）が分析の動機として記述されており、特定ケース群との関連が推測可能。変更内容自体は汎用的パターンであるため 2 とする。 |

## 総合コメント

本変更は、論文の中核概念である「手続き間トレース（interprocedural tracing）」を COUNTEREXAMPLE ブロック内で構造的に要求するという、最小限かつ的を射た改善である。論文 §4.1.1 のエラー分析で指摘された「incomplete execution tracing」と「dismissing subtle differences」の両方に対処する設計であり、研究の方向性と整合している。

1 行追加という変更規模の小ささ、影響範囲の限定性（NOT_EQUIVALENT 主張時のみ）、および言語非依存の汎用性から、overfitting のリスクは低い。唯一の懸念は、Call path 引用の義務化が NOT_EQUIVALENT の正当な判定を若干困難にする可能性だが、現在の主要な失敗パターン（EQUIVALENT → NOT_EQUIVALENT の誤判定）を考慮すると、この方向の調整は合理的である。
