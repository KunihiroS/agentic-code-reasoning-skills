# Iteration 11 Discussion

- 検索: 検索なし（理由: 提案の中心は UNVERIFIED と verdict 依存性の書き分けという一般的な推論運用原則であり、特定研究用語や外部主張への強い依拠はないため）

## 総評
提案の狙い自体は理解できる。現行 SKILL.md では Step 4 の「UNVERIFIED を書くこと」と Step 5.5 の「その仮定が結論を変えない」との関係が 1 句に圧縮されており、compare 実行時に「未検証だが harmless と書けば結論確定してよい」という雑な通し方を誘発しうる。その意味で、未検証リンクの“記録”と“verdict 依存性”を分解したいという問題設定は妥当。

ただし、今回の具体案は failed-approaches.md の原則 2 にかなり近い。とくに Trigger line の「If the answer depends on an UNVERIFIED link, do not finalize from that link alone ...」は、失敗原則 2 の「未検証の最弱リンクが verdict を左右しうるなら確定しない」の再演に見える。文言の置換としては小さいが、compare の分岐としては“未検証リンクがあると provisional/LOW confidence へ倒す既定動作”を追加しており、過去失敗の本質に触れている。

## 監査観点別コメント

### 1) 既存研究との整合性
- 研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を壊してはいない。
- ただし今回の変更は、研究のコア強化というより Guardrail/自己チェックの運用変更に近い。README / design の趣旨とは整合するが、論文由来の新規アイデア導入ではなく、既存ガードレールの分岐変更である。

### 2) Exploration Framework のカテゴリ選定
- 提案者はカテゴリ E（表現・フォーマット改善）としているが、実質は E 単独ではない。
- 変更の本体は wording cleanup ではなく、UNVERIFIED を見たときの結論確定条件を変える decision policy の変更であり、D（メタ認知・自己チェック強化）の比重が大きい。
- したがって「E として全く不適切」とまでは言わないが、監査上は「表現改善に見せた判断分岐変更」と読むべき。

### 3) EQUIVALENT / NOT_EQUIVALENT の両方向への作用
- 正方向の効果:
  - 偽 EQUIVALENT: 未検証リンクを harmless と言い換えて押し切る誤りは減りうる。
  - 偽 NOT_EQUIVALENT: 逆に、未検証リンクを差分の支えにして早く NOT_EQUIVALENT を確定する誤りも、provisional/LOW confidence へ戻すなら減りうる。
- 逆方向の副作用:
  - ただし実効的には「どちらの結論でも、未検証リンクが verdict-bearing なら確定しない」に寄るため、両方向の精度改善というより“決めない方向”へのバイアスが強い。
  - Objective の停滞対策観点では、compare の観測可能差が firm answer から provisional/LOW confidence へ寄るだけだと、実行時アウトカム差はあるが正答率向上に直結するとは限らない。
- 結論: 片方向最適化ではないが、両方向改善の形は「誤答を減らす」より「確定回答を減らす」に近く、過保守化リスクがある。

### 4) failed-approaches.md との照合
- 本質的再演の懸念が強い。
- failed-approaches 原則 2 は、未確定性や脆い仮定を Guardrail 化して保留側へ倒す既定動作を増やすな、と言っている。
- 今回の Trigger line はまさに「verdict を支える未検証リンクがあるなら finalize しない」という保留トリガーであり、表現は少し違ってもメカニズムは近い。
- 提案文には「局所条件にだけ作用」とあるが、compare の最終結論直前チェックに入る MUST である以上、局所補助手順ではなく結論ガードレール化される。

### 5) 汎化性チェック
- 提案文中に具体的な数値 ID、特定リポジトリ名、テスト名、コード断片の引用はない。ルール違反は見当たらない。
- ドメイン依存性も強くない。third-party / source unavailable / verdict dependence は言語横断で成立する。
- ただし暗黙には「外部ライブラリや未読定義を含む比較で、結論を保留しうる」場面を主対象にしており、compare 全体より不確実性処理に寄った改善である。

### 6) 全体の推論品質への期待効果
- 良い点: UNVERIFIED の記録と verdict dependence の判定を分ける発想は、曖昧な自己正当化を減らす可能性がある。
- 懸念点: その効き方が「より正しく比較する」より「未検証なら止まる」に寄ると、推論品質の改善ではなく確定回避の最適化になる。
- したがって、compare 品質向上の核にするなら、保留条件の追加ではなく「未検証リンクが verdict-bearing かを見極めるための追加探索要求」を主に据えるべきで、結論停止を主動作にしない方がよい。

## 停滞診断
- 懸念 1 点: 提案は audit rubric に刺さる説明（“未検証だが harmless の雑な通しを防ぐ”）としては筋が良いが、compare 実行で増えるのが firm な正解ではなく provisional/LOW confidence なら、実行時アウトカム差が「慎重化」止まりになり、compare の意思決定改善としては停滞しうる。

- 「探索経路の半固定」: NO
- 「必須ゲート増」: YES
  - 原因文言: `If the answer depends on an UNVERIFIED link, do not finalize from that link alone; keep the verdict provisional or LOW confidence ...`
- 「証拠種類の事前固定」: NO

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 観測可能な差はある。未検証リンクが verdict-bearing な場合、以前は ANSWER を確定しえた場面で、変更後は provisional/LOW confidence または追加探索要求が出る。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line の自己引用が差分プレビュー内にあるか: YES
  - ただし差分の主作用は「未検証リンクあり → finalize しない」であり、分岐の具体化はできている一方、過去失敗と近い分岐でもある。

- 2) Failure-mode target:
  - 目標は両方。
  - メカニズムは「UNVERIFIED を harmless assumption で通す雑な確定」を減らすこと。
  - ただし副作用として、偽 EQUIV / 偽 NOT_EQUIV を減らすより、未確定回答を増やす方向に働きやすい。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か?: NO
  - impact witness 要求: N/A

- 3) Non-goal:
  - 探索経路の半固定や証拠種類の固定は増やさない、という境界は明示されている。
  - しかし実装文言は「結論停止」を Guardrail 化しており、non-goal の宣言だけでは failed-approaches 原則 2 から十分に離れられていない。

- Discriminative probe:
  - 抽象ケースの記述はあり、変更前は未検証ライブラリ解釈を harmless と見なして誤った確定回答を出しうる、変更後は provisional/LOW confidence へ寄る、という差は説明できている。
  - ただしこの改善は“分岐の識別精度向上”というより“結論停止”に依存している。既存文言の置換として説明されている点は良いが、compare をよりよく決める probe になりきっていない。

- 支払い（必須ゲート総量不変）の A/B 対応付け:
  - YES。Payment が明示されている点は良い。

## 最大のブロッカー
failed-approaches.md 原則 2 の本質的再演。特に「verdict-bearing な UNVERIFIED link があるなら finalize しない」という新 MUST は、過去に失敗した“未確定性を Guardrail 化して保留側へ倒す既定動作”とほぼ同型。

## 修正指示
1. `do not finalize ... provisional or LOW confidence` を主ルールにしない。結論停止ではなく、まず「そのリンクが verdict-bearing かを切り分けるために何を追加で探すか」を要求する文言へ置換すること。
2. 支払いは維持しつつ、Step 5.5 の MUST 追加ではなく Step 4 の UNVERIFIED 記録文を具体化する方向へ寄せること。つまり guardrail 追加ではなく trace table の記録粒度改善として実装すること。
3. カテゴリ表記を E 単独のままにせず、少なくとも D 要素を含むと認めたうえで、compare の改善が「保留増」ではなく「追加探索の質向上」であると分かる Trigger line に差し替えること。

承認: NO（理由: failed-approaches.md 原則 2 の本質的再演で、未検証リンクを理由に結論を保留側へ倒す Guardrail を再導入しているため）