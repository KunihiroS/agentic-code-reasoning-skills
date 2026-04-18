# Iteration 20 — Discussion

## 既存研究との整合性
- 検索なし（理由: 一般原則の範囲で自己完結）。
- README.md / docs/design.md の研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）とは表面的には整合する。差分の重要度を明示して反証の当たりどころを決める、という狙い自体は Compare の補助ヒューリスティックとして理解可能。
- ただし研究コアが強いのは「per-test iteration と反証義務」であり、反証対象の優先順位を固定すること自体はコアではない。したがって、導入するなら exploration を狭めない弱い補助に留める必要がある。

## Exploration Framework のカテゴリ選定
- カテゴリ C（比較の枠組みを変える）の選定自体は妥当。
- 理由: 提案の中心は「差異を CONTRACT / DATA-STATE / INTERNAL に分類し、比較粒度と反証優先順位を変える」ことであり、これは Objective.md の C「差異の重要度を段階的に評価する」「変更のカテゴリ分類を先に行う」に一致する。
- ただし、現 proposal の書き方は「比較枠組みの変更」から一歩進んで「Step 5 の探索順序の半固定」に踏み込んでいる。カテゴリ選定は合っているが、実装文言が failed-approaches に近づいている点は要注意。

## compare 影響の実効性チェック
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内に含まれているか？ YES
  - 評価: 条件と行動は一応変わっている。Before は「任意順」、After は「最高ティア差分から」。よって単なる理由の言い換えではない。
  - ただし、変わる意思決定ポイントが「最初に何を反証するか」に偏っており、「結論を出す / 保留する / 追加で探す」の分岐条件そのものはまだ弱い。compare への効きはゼロではないが、実効差は限定的。
- 2) Failure-mode target:
  - 狙いは両方。
  - 偽 EQUIV 側: 契約差分やデータ差分を internal 相当として軽視する誤りを減らしたい。
  - 偽 NOT_EQUIV 側: 内部差分をそのまま挙動差と見なして過反応する誤りを減らしたい。
  - メカニズムは理解できるが、「highest tier first」が本当に両方向で効くかは未整理。高ティア差分に寄せるほど、低ティアだが実テストに効く差分の拾い直しが遅れるリスクもある。
- 3) Non-goal:
  - 証拠種類の事前固定をしない、観測境界へ過度に還元しない、探索順序を固定しない、という境界条件の宣言は適切。
  - しかし実際の追加文言「Use Tier to choose the first refutation target in Step 5 (highest tier first).」は、この Non-goal と少し緊張関係にある。宣言上は避けると言っているが、実装上は refutation priority を半固定している。
- Discriminative probe:
  - 抽象ケース: 2 つの変更が同じ出力を返すように見えるが、一方だけ契約上の例外条件や永続状態更新の条件を変えているケース。
  - 変更前は、目立つ内部差分やローカル制御フローから先に追って「違いはあるがテスト影響は薄そう」または逆に「内部差分があるので違いそう」とぶれやすい。変更後は、契約/データ差分を先に ledger 化できれば、どの差分が test outcome に写像されうるかの説明はしやすくなる。
  - ただしこれは「最初に見る順番の改善」としては分かる一方、既存文言の置換・再配置ではなく必須工程の純追加に近い。
- 支払い（必須ゲート総量不変）の明示:
  - NO。proposal は「2 行追加のみ」「必須ゲート純増なし」と主張するが、DELTA LEDGER 1–3 rows と highest-tier-first rule は compare の実質的な必須作業を増やしている。どの既存必須要件を optional 化/統合して支払うのかが書かれていない。

## EQUIVALENT / NOT_EQUIVALENT への作用
- EQUIVALENT 判定への正方向:
  - INTERNAL 差分を CONTRACT / DATA と切り分けられれば、内部実装差に引っ張られた偽 NOT_EQUIV を下げる可能性はある。
- EQUIVALENT 判定への負方向:
  - 「highest tier first」が強く働くと、高ティアに見える差分の説明に寄り、実テスト上は無害な差分でも保守的に NOT_EQUIV へ倒れやすくなる恐れがある。
- NOT_EQUIVALENT 判定への正方向:
  - 契約差分・データ差分を先に言語化できれば、偽 EQUIV の一因である「差分の重要度の見誤り」は減らせる。
- NOT_EQUIVALENT 判定への負方向:
  - 低ティア扱いされた差分でも、実際には既存テストの assertion に直結する場合がある。その場合、優先順位づけが探索遅延として働き、反例発見を鈍らせる。
- 総評:
  - 片方向最適化を避けたいという狙いは良いが、現文言のままだと「両方向に効く一般原則」というより「Step 5 の入口を highest-tier-first に寄せる局所最適化」に見える。したがって両方向改善の主張は、まだ設計より強い。

## failed-approaches.md との照合
- 「探索経路の半固定」に該当するか: YES
  - 原因文言: 「Use Tier to choose the first refutation target in Step 5 (highest tier first).」
  - failed-approaches.md は「どこから読み始めるか」「既存の反証優先順位をある局所観点へ差し替える変更」を危険視している。今回の文言はまさに Step 5 の優先順位を tier 観点へ差し替えている。
- 「必須ゲート増」に該当するか: YES
  - 原因文言: 「DELTA LEDGER (1–3 rows, before edge cases): ...」
  - compare テンプレートに新しい記入義務が増えている。しかも payment の明示がない。
- 「証拠種類の事前固定」に該当するか: NO
  - Tier 自体は証拠ソース（テスト、仕様、ドキュメント等）を固定していない。この点は proposal の説明どおり比較的安全。
- 本質的な再演か:
  - はい、完全一致ではないが、本質的には「反証の優先順位を特定の局所観点で半固定する」失敗原則にかなり近い。

## 汎化性チェック
- proposal 文中に、具体的な数値 ID、ベンチマーク対象リポジトリ名、テスト名、コード断片の引用は見当たらない。明示的なルール違反はない。
- CONTRACT / DATA-STATE / INTERNAL という分類は言語非依存で、特定ドメインに閉じていない。
- ただし「contract」という語は API/インターフェース中心の設計を暗に想起させるため、非 OOP・非公開 API 中心のコードにも当てはまるよう、「externally observable behavior / persisted state / internal mechanism」などの補助説明があるとさらに安全。

## 停滞診断
- 懸念点（1 点だけ）:
  - proposal は audit rubric に刺さりやすい説明（両方向改善、Non-goal、failed-approaches 整合）の密度は高いが、compare の実際の意思決定で変わるのは「最初にどれを反証するか」だけで、結論の分岐条件そのものはあまり変えていない。監査に通りやすいが compare を大きく動かさない停滞型に寄る懸念がある。

## 全体の推論品質への期待効果
- 良い点:
  - 差分を無差別に扱わず、観測可能性に近い粒度で整理させる発想は、compare の雑な過大評価/過小評価を減らす方向に働きうる。
  - 特に「Observable=[what would differ]」を短く言語化させる部分は、反証対象の見通しを良くするので有益。
- 限界:
  - 本当に効いている部分は「Tier」よりも「Observable を先に書かせること」に見える。highest-tier-first まで固定すると gains より regression risk が増える。
  - また ledger を新設するなら、どこかの既存必須要素を統合して総量を保たないと、compare 品質改善ではなく template 充足負荷の増加になりやすい。

## 修正指示
1. 「highest tier first」を削り、Tier は refutation の固定優先順位ではなく「見落とし防止の補助ラベル」に弱めること。
   - 追加ではなく置換を優先し、「Use Tier to choose the first refutation target...」は削除し、代わりに「If a difference is classified as INTERNAL, explicitly state why it would still be observable to existing tests before treating it as decisive.」のような判定条件寄りの1行へ差し替えるのがよい。
2. DELTA LEDGER を足すなら、既存の EDGE CASES 節か pass-to-pass 節の一部を統合して“支払い”を明示すること。
   - 例: EDGE CASES の各項目に Tier/Observable を吸収し、独立した新ゲートにしない。
3. compare への実効差を強めるなら、順序指定ではなく分岐条件として書くこと。
   - 例: 「INTERNAL 差分だけで NOT EQUIVALENT を主張するなら、その差分が既存テストの assertion / pass-fail にどう写像されるかを先に示す」のように、結論条件を変える1行へ再設計する。

## 総合判断
- 提案の狙い自体は理解でき、カテゴリ選定や汎化性にも大きな問題はない。
- しかし現状の核となる変更は、failed-approaches.md が禁じる「探索経路の半固定」と「実質的な必須ゲート増」を同時に含んでいる。しかも payment が明示されていないため、compare の実効改善より template 負荷の増加として出るリスクが高い。

承認: NO（理由: failed-approaches.md にある「反証優先順位の局所観点への差し替え」という本質的失敗の再演であり、highest-tier-first が探索経路の半固定として働くため）
