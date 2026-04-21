# Iteration 16 — Overfitting 監査

## 判定: PASS
## 合計スコア: 16/18

| # | 項目 | スコア | 根拠 |
|---|------|--------|------|
| R1 | 汎化性 | 3 | diff/rationale は SKILL.md 自身の文言引用と抽象的な推論用語（test-facing obligation, preserved/broken/unresolved など）に留まっており、ベンチマーク対象リポジトリの固有識別子、実装コード引用、テスト名・ID・関数名・パスは含まれていない。変更内容も「意味差を test-facing obligation 単位で扱う」という一般的な比較手法で、任意の言語・フレームワーク・プロジェクトへ適用可能。 |
| R2 | 研究コアの踏襲 | 3 | README.md と docs/design.md、論文冒頭が示す研究コアは「番号付き前提」「仮説駆動探索」「手続き間トレース」「必須反証」を証拠付きで行う semi-formal reasoning である。本変更は compare モード内の意味差の扱いを明確化するだけで、これらの中核構造を削らず、むしろ traced difference を明示的に比較表へ残す運用を強めている。 |
| R3 | 推論プロセスの改善 | 3 | 変更は結論を直接指示せず、「意味差発見後に何を比較単位として保持するか」という推論手順そのものを改善している。従来の単発 path ベースの no-impact 吸収を、obligation 単位の preserved / broken / unresolved 分類へ置き換えることで、比較粒度と判断タイミングを具体的に改善している。 |
| R4 | 反証可能性の維持 | 3 | semantic difference を即座に吸収せず、まず test-facing obligation に照らして preserved/broken/unresolved を明示させるため、差分を見落として EQUIVALENT に早期収束するリスクを下げる。NOT EQUIVALENT 時の counterexample 要件や既存の refutation step も残っており、反証可能性は弱まっていない。 |
| R5 | 複雑性の抑制 | 2 | 追加は 4 行＋checklist 1 行置換で局所的だが、新たに「obligation」「PRESERVED BY BOTH / BROKEN IN ONE CHANGE / UNRESOLVED」という分類語彙を導入しており、比較手順の抽象度はやや上がる。failed-approaches.md の「新しい抽象ラベルで強くゲートしすぎない」に近い懸念はあるため満点ではないが、置換中心で総量は小さく、不当に複雑というほどではない。 |
| R6 | 回帰リスク | 2 | 影響範囲は compare の semantic-difference 処理に限定されており広範ではない一方、差分吸収の閾値を変えるため既存に正しく解けていた一部 EQUIVALENT/NOT_EQUIVALENT 判定へ判断バイアスを与える可能性はある。特に failed-approaches.md が警告する「抽象ラベルによる差分ゲート化」に部分的に接するので軽微な回帰懸念は残るが、構造全体を崩す変更ではなく改善見込みが上回る。 |

## 総合コメント

この変更は、特定ケースの救済ではなく compare における「意味差の畳み方」を一般化して調整する提案になっており、R1 の観点では良好です。README.md・docs/design.md・論文が重視する semi-formal reasoning のコア、すなわち explicit premises、interprocedural tracing、refutation を維持したまま、差分を test-facing obligation 単位で保留・分類してから verdict に反映するようにした点は、推論プロセス改善として妥当です。

一方で、failed-approaches.md には「差分の昇格条件を新しい抽象ラベルで強くゲートしすぎない」という失敗原則があり、本変更はそこに部分的に近接します。ただし今回は巨大な新ゲート追加ではなく、既存の no-impact 判定文をより明示的な obligation 分類へ置換した局所変更で、複雑性も限定的です。よって総合的には PASS と判断しますが、今後のベンチマークでは「unresolved が過剰に増えて保守化しないか」「preserved by both 判定が別名の再収束規則になっていないか」を重点観察すべきです。
