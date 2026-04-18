# Iteration 26 Discussion

## 監査サマリ
- 検索: 検索なし（理由: 提案の中核である「差分を影響軸・発火前提・オラクル接点で分類して反例形状を具体化する」は一般的な推論設計の範囲で自己完結しており、特定研究の固有概念への依拠が強くないため）
- 総評: 方向性自体は理解できるが、現状の proposal は compare の意思決定点を両方向に十分具体化できていない。特に NOT_EQUIVALENT 側への作用が実装文面から読み取りにくく、しかも「first write」「then trace」により探索順序を半固定しやすい。

## 1. 既存研究との整合性
- README.md と docs/design.md が強調する研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証である。
- 今回の提案は、そのコア自体を壊すものではなく、compare モード内で counterexample 記述の粒度を変える提案として読める。
- ただし、研究コアは「具体アイテムごとの反証・追跡」であり、探索入口を先に分類ラベルへ寄せすぎると、docs/design.md の「per-item iteration as the anti-skip mechanism」よりも「最初の枠組み作り」が前面に出る。そのため整合は部分的で、強化というより置換に近づく懸念がある。

## 2. Exploration Framework のカテゴリ選定
- 提案者はカテゴリ C（比較の枠組みを変える）を選んでいる。
- これは大枠では妥当。なぜなら変更対象は test ごとの比較そのものではなく、差分をどう表象して compare に持ち込むか、という比較フレームだから。
- ただし実際の diff preview は「分類ラベルの導入」だけでなく、「first write」「build ... then trace」によって探索順序まで変えている。これは C に加えて A/B の性質も帯びる。
- したがってカテゴリ宣言は完全に不適切ではないが、「比較枠組みの変更」に留めた説明に対し、実装文面は探索順序変更まで含んでおり、説明と実装の一致度はやや弱い。

## 3. compare 影響の実効性チェック
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？: YES
  - Trigger line（発火する文言の自己引用）が差分プレビュー内にあるか？: YES
  - ただし内容評価: NO（実質不足）
    - Before/After は EQUIVALENT 主張時の探索記述しか変えておらず、NOT_EQUIVALENT を出す/保留する/追加で探す分岐条件が明示されていない。
    - そのため compare の意思決定点を「両方向の判定分岐」として変えているとは言いにくい。理由の言い換えではないが、分岐の片側しか具体化できていない。
- 2) Failure-mode target:
  - 狙いは両方と書かれているが、実装文面から直接減らせそうなのは主に偽 EQUIV。
  - メカニズム: 反例不在を主張する前に、差分を「どの軸で割れるか」に言語化することで、見落とし反例を探しやすくする。
  - 一方で偽 NOT_EQUIV 低減の経路は弱い。proposal には「どの軸も明示できない見かけ差分の暴発が減る」とあるが、SKILL 差分プレビューの文面はそれを判定ルールとして十分表現していない。
- 3) Non-goal:
  - 「STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や観測境界の制限ルールは変更しない」は境界条件として適切。
  - ただし、探索経路の半固定・必須ゲート増・証拠種類の事前固定を避けるための条件としては足りない。分類ラベル記入を mandatory にするなら、そのぶん何を optional 化/統合するかの対応付けをもっと明示すべき。

## 追加チェック
- Discriminative probe:
  - 抽象ケース: 2 つの変更が同じ出力を返すが、片方だけ特定前提下で例外型が変わる。
  - 変更前は「通常入力の同値」に引っ張られて偽 EQUIV が起きうる。変更後は axis=exception, trigger=特定前提, oracle=その assert/check を先に言語化できれば回避しやすい。
  - ただしこれは EQUIV 側の改善説明としては機能するが、偽 NOT_EQUIV をどう減らすかの対称的説明にはなっていない。
- 「支払い（必須ゲート総量不変）」の A/B 対応付けが proposal 内で明示されているか:
  - 一応「既存文言の置換のみ（合計4行、追加の必須ゲート純増なし）」とは書かれている。
  - しかし、どの mandatory を削り/統合し、その代わりに何を入れるのかの対応は曖昧。総量不変の主張はあるが、compare の実効差を判断するにはまだ粗い。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- EQUIVALENT 側:
  - 改善余地はある。NO COUNTEREXAMPLE EXISTS 節の具体化として機能し、反例探索の取りこぼしを減らしうる。
  - 特に SKILL.md 現行の「what test, what input, what diverging behavior」を、より観測可能な壊れ方に寄せる点は有効。
- NOT_EQUIVALENT 側:
  - 提案文では効くと主張しているが、差分プレビューでは「どの条件で NOT_EQUIVALENT を出すのか」が不足。
  - 現行の COUNTEREXAMPLE 節は既に十分に具体的で、そこへ ledger を前置すると、逆に「まず分類が埋まる差分だけを優先する」バイアスが入りうる。
  - その結果、明瞭な構造差や直接的テスト差分をすぐ結論化できる場面でも、先に ledger 化を要求して compare を重くする恐れがある。
- 実効的差分の評価:
  - 実際には片方向寄り。proposal の中心効能は「反例不在主張の精密化」であり、NOT_EQUIVALENT 判定の加速や精度向上は副次的・未具体化。
  - このままだと focus_domain の片方向最適化になりやすい。

## 5. failed-approaches.md との照合
- 「探索経路の半固定」: YES
  - 原因文言: 「first write a Divergence Ledger」「then use ANALYSIS」「Before comparing, build ... then trace」
  - 問題点: 何を先に書くか、どの枠を先に埋めるかを compare 全体の入口として固定している。
- 「必須ゲート増」: NO
  - 明示上は置換であり、純増とまでは言えない。
  - ただし実務上は新しい準備段階の義務化に近く、NO だが軽い懸念あり。
- 「証拠種類の事前固定」: YES寄り
  - proposal は「証拠ではなく差分分類」と説明しているが、impact axis / trigger / oracle touchpoint の固定タグで反例記述を始めさせるため、探索対象の見え方を事前にかなり規定している。
  - failed-approaches.md の「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」に本質的に近い。
- 本質的再演か:
  - 完全一致ではないが、少なくとも「探索入口を狭める」という失敗原則に接続している。現状の wording だと再演リスクは無視できない。

## 6. 汎化性チェック
- 明示的なルール違反チェック:
  - proposal 内に具体的な数値 ID: なし
  - ベンチマーク対象リポジトリ名: なし
  - 特定テスト名: なし
  - ベンチマーク対象の実コード断片: なし
- したがって、明白な R1 違反は見当たらない。
- ただし暗黙の前提として、差分を output/exception/side-effect/perf などで先に切る発想は、観測可能な外部振る舞いが明瞭なタスクには合う一方、設定解決・型レベル制約・非機能要件・複合的プロトコル整合性のような差分では分類が粗くなりうる。
- つまり固有事例への過適合ではないが、ドメイン非依存の万能フレームとしては少し振る舞い中心に寄っている。

## 7. 停滞診断
- 懸念点（1点だけ）:
  - 今回の提案は「監査 rubric に刺さる説明強化」には見えやすいが、compare の最終意思決定をどこで変えるかが EQUIVALENT 側以外で曖昧なため、監査では通りやすくても benchmark の compare 判定を実際にはあまり動かさない恐れがある。

## 8. 推論品質への期待効果
- 良い面:
  - 反例の形状を「観測可能な破れ方」に寄せることで、EQUIVALENT 側の雑な無反例宣言を抑えやすい。
  - 現行 compare テンプレートの「what test / input / diverging behavior」を、より再利用しやすい抽象粒度に整える効果はある。
- 限界:
  - NOT_EQUIVALENT 側の分岐強化が弱く、compare 全体の精度改善というより「no counterexample exists の書き方改善」に寄っている。
  - mandatory な先行 ledger は、構造差から即断できるケースや、既に十分具体的な counterexample が見えているケースでノイズになりうる。

## 修正指示（2〜3点）
1. 「first write」「build ... then trace」を削り、ledger を mandatory な前置段階ではなく、NO COUNTEREXAMPLE EXISTS 節の置換として限定してください。
   - 置換対象を明示: 現行の「what test, what input, what diverging behavior」を、ledger 風の記述に差し替える。
   - これなら支払いが明確で、探索経路の半固定を弱められます。
2. Decision-point delta を両方向で書き直してください。
   - EQUIVALENT だけでなく、NOT_EQUIVALENT についても Before/After の IF/THEN を 2 行で追加し、「どの条件で結論を出す/保留する/追加探索するか」を明示してください。
   - とくに「分類不能な見かけ差分では即 NOT_EQUIV に行かず、既存の test outcome 差分まで追う」など、行動分岐として書く必要があります。
3. 分類ラベル集合を固定リストとして強く押し出しすぎないでください。
   - output/exception/side-effect/perf は例示に下げ、必須なのは「trigger precondition と oracle touchpoint を伴う差分記述」だけに縮めるほうが、failed-approaches.md の再演リスクを減らせます。

## 結論
承認: NO（理由: compare への実効差が片方向寄りで、NOT_EQUIVALENT 側の意思決定変更が未具体化のまま、探索経路の半固定を招く文言が前面に出ているため）
