# Iter-4 Discussion

## 総評
提案の主眼は、compare の STRUCTURAL TRIAGE にある早期 NOT EQUIVALENT 条件の曖昧さを減らし、「構造差が見えた」ことと「関連テスト結果が必ず分岐する」ことを切り分ける点にあります。これは SKILL.md の既存コア（D1/D2、反証、テスト基準の比較）を保ったまま、早すぎる NOT_EQUIVALENT へのショートカットを抑える小変更として妥当です。

ただし、効き方は本質的に対称ではありません。直接効くのは主に偽 NOT_EQUIVALENT の削減であり、偽 EQUIVALENT を能動的に減らす変更ではありません。したがって proposal の「両方向の誤判定が減る」は少し言い過ぎで、そこを正せば監査 PASS の下限は満たしやすいです。

## 1. 既存研究との整合性
注: DuckDuckGo MCP の search は今回複数クエリで結果を返せなかったため、同じ DuckDuckGo MCP の fetch_content で公開 URL を確認しました。

- URL: https://arxiv.org/abs/2603.01896
  - 要点: semi-formal reasoning は「explicit premises, trace execution paths, formal conclusions」により unsupported claims や case-skip を防ぐ certificate として働く。
  - 整合性: 今回の提案は compare の結論ショートカット条件を D1/D2 に結び直すもので、研究コアを変えず certificate の判定条件を明確化する方向。研究と整合的。

- URL: https://en.wikipedia.org/wiki/Regression_testing
  - 要点: 回帰テストでは change impact analysis により「どのテストが適切な部分集合か」を見極める考え方が一般的。
  - 整合性: 構造差の有無だけでなく relevant tests への影響で絞る、という提案の発想は回帰テストの一般原則と噛み合う。

- URL: https://en.wikipedia.org/wiki/Change_impact_analysis
  - 要点: impact analysis は変更の結果何が影響を受けるかを traceability / dependency の観点で絞る。
  - 整合性: 「relevant test が import/load/execute する対象の欠落」に限定して早期 NOT_EQUIVALENT を許す案は、単なる差分検出ではなく依存・到達性ベースの影響分析に寄せるもので妥当。

- URL: https://en.wikipedia.org/wiki/Equivalence_checking
  - 要点: equivalence は本来、同一入力条件下で同一の観測可能結果を生むかで見るべきで、表面的な構造差それ自体ではない。
  - 整合性: proposal は「構造差=非同値」という短絡を弱めるため、等価性判定の一般原則に沿う。

研究とのズレとしては、今回の補強は「探索効率」よりも「早期結論条件の明確化」に寄っており、研究が強調する per-test tracing を増やすものではありません。よって研究整合性は高いが、効果は局所的です。

## 2. Exploration Framework のカテゴリ選定は適切か
結論: おおむね YES。

- 提案の実体は「新しい手順追加」ではなく、「既存の早期 NOT_EQUIVALENT 許可文の意味を具体化」なので、カテゴリ E. 表現・フォーマット改善 に置くのは自然です。
- ただし、単なる wording polish ではなく compare の意思決定条件を実際に変更しています。したがって E の中でも「曖昧文言の具体化による decision-point 修正」と明示したのは適切です。
- 逆にカテゴリ C（比較の枠組み変更）ほど大きくはありません。D1/D2 は既存のままで、比較単位や分析順序を変えていないためです。

## 3. EQUIVALENT / NOT_EQUIVALENT の両判定への作用
### 変更前との実効差分
変更前:
- S1/S2 で「clear structural gap」と見えたら、そのまま早期 NOT_EQUIVALENT に進みやすい。

変更後:
- その structural gap が D2 の relevant-test scope 内で D1 の結果差に必然的に効くと説明できる場合だけ、早期 NOT_EQUIVALENT を許す。
- そう言えない structural gap は ANALYSIS へ回す。

### 両方向への作用評価
- NOT_EQUIVALENT 側:
  - 直接効く。relevant tests に無関係な補助ファイル差分や到達しないデータ差分で premature NO を出す偽 NOT_EQUIVALENT を減らせる。
- EQUIVALENT 側:
  - 間接的には効く。従来なら早期 NO に倒れていた事案を ANALYSIS に戻すことで、最終的に EQUIVALENT に到達しやすくなる。
  - ただし、偽 EQUIVALENT を直接減らすメカニズムではない。隠れた意味差の発見能力を強める変更ではないため、proposal の「両方向の誤判定が減る」は控えめに言い換えるべき。

### 片方向最適化か
- 直接機序はかなり片方向です。早期 NOT_EQUIVALENT の発火条件だけを狭めるためです。
- しかし、逆方向の悪化が明白とまでは言えません。理由は、真に relevant test に効く structural gap は引き続き S2 と整合的に早期 NO を出せるからです。
- したがって「片方向にしか効かないので却下」ではなく、「片方向の主作用であることを proposal 自身が正直に書け」が適切です。

## 4. failed-approaches.md との照合
結論: 本質的再演ではない可能性が高い。

- 「探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更」
  - 今回は新しい証拠カテゴリを増やしていない。既存の D1/D2 と S2 の接続を明文化する提案であり、証拠種類の固定化には当たりにくい。
- 「探索ドリフト対策を追加する際は、探索の自由度を削りすぎない」
  - 読む順序や探索開始点を固定していない。早期ショートカット条件だけを狭める変更なので、探索経路の半固定とは言いにくい。
- 「結論直前の自己監査に、新しい必須のメタ判断を増やしすぎない」
  - 新欄や新ゲートは追加していない。既存 3 行の条件文置換に留まる。

注意点:
- 文言の「necessarily affects D1」が強すぎると、実装上は新しい証明義務として働く恐れはあります。これは failed-approaches の「実質的な新ゲート」に近づくリスクです。
- ただし proposal は例示を S2 の import/load/execute に寄せており、まだ本質的再演とまでは言えません。

## 5. 汎化性チェック
結論: 重大な違反は見当たりません。

- proposal 内に、具体的なベンチマーク case ID、対象リポジトリ名、実テスト名、実コード断片は含まれていません。
- D1/D2 や import/load/execute は SKILL.md 内の一般概念・自己引用の範囲であり、R1 の減点対象外に近いです。
- 提案は特定言語に閉じていません。import/load/execute は言語横断の一般表現として機能します。

軽微な懸念:
- 「import/load/execute」に例示が寄ることで、ビルド設定・宣言的設定・メタデータ駆動のテスト到達性を持つ環境をやや弱く表現しています。これは汎化性違反ではないが、例示が実質的に code-loading 系へ寄りすぎる懸念はあります。

## 6. 全体の推論品質への期待効果
期待できる改善:
- structural difference を semantic difference と取り違える短絡の抑制
- compare における early commitment の減少
- D1/D2 を実際のショートカット判断に接続することで、テンプレート内の整合性が上がる

改善が限定的な点:
- per-test tracing の質そのものは上げない
- hidden semantic difference の発見能力は強化しない
- 真の NOT_EQUIVALENT の取りこぼしを減らすより、偽 NOT_EQUIVALENT の抑制に寄る

総合すると、「compare の判定品質を少しだけ安定化する局所改善」としては見込みがあります。大幅改善ではないが、運用ルールにある「安全そうだが効き目が薄いだけで NO にしない」に照らすと、採る価値はあります。

## 停滞診断（必須）
- 懸念 1 点:
  - 「監査 rubric に刺さる説明強化」へ偏る危険はある。特に proposal の記述は監査上きれいだが、実際に compare の意思決定を変えるのは「早期 NO の発火条件が狭まる」一点に限られる。したがって、効果説明を盛りすぎると audit-friendly だが compare への実効差分は小さく見える。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO（ただし “necessarily affects D1” を強い証明義務として書くと実質 YES に寄る）
  - 証拠種類の事前固定: NO

## compare 影響の実効性チェック（必須）
- 1) Decision-point delta:
  - 変わる意思決定ポイントは「STRUCTURAL TRIAGE の直後に NOT_EQUIVALENT を出すか / ANALYSIS に進むか」。条件は「構造差がある」から「relevant-test scope 内で結果差に必然的に効く構造差がある」へ変わる。

- 2) Failure-mode target:
  - 主対象は偽 NOT_EQUIVALENT。
  - メカニズムは、スコープ外 structural gap による premature NO を止め、テスト到達性のある差だけを shortcut 対象に残すこと。
  - 偽 EQUIVALENT は間接改善のみで、主対象ではない。

- 3) Non-goal:
  - 探索順序は固定しない。
  - 新しい必須欄や自己監査ゲートは増やさない。
  - import/load/execute 以外の証拠を排除しない。要件は「relevant tests への影響説明」であって、証拠種類の限定ではない。

## 最大の論点
最大の論点は、「この変更は両方向改善ではなく、主として早期 NO の絞り込みである」という点です。これは却下理由ではありませんが、proposal の効果記述が強すぎると監査上の説明過多に見えます。

## 修正指示（2〜3点）
1. 「両方向の誤判定が減る」を縮める。
   - 追加するより、現行の強い主張を削ることを推奨。
   - 置換案: 「主に偽 NOT_EQUIVALENT を減らす。EQUIVALENT 側の改善は、早期 NO を ANALYSIS に戻す間接効果に限られる。」

2. 「necessarily affects D1」を少し弱め、S2 の既存表現に寄せる。
   - 追加の証明義務を増やすより、文言を統合するのがよい。
   - 置換案: 「has a structural gap on the path of D2’s relevant tests」または「is omitted from a file/module/data path that a relevant test imports, loads, executes, or otherwise depends on」。
   - これにより “必然性のメタ判断” より “既存の到達性確認” に近づく。

3. 例示の支払いを入れる。
   - import/load/execute の例を追加するなら、別の箇所で「missing file, missing module update, missing test data」の旧例をそのまま重ね書きしないこと。
   - 旧例を新例に統合して、必須文の総量を増やさない形にするべき。

## 結論
この proposal は、研究コアや failed-approaches の禁則を大きく踏み外さず、compare の一つの誤り方（構造差の過大評価）に対して小さく効く改善です。主作用が片方向であることを正直に書き直し、「necessarily affects D1」を実質ゲート化しすぎないよう調整すれば、監査 PASS の下限は満たせます。

承認: YES
