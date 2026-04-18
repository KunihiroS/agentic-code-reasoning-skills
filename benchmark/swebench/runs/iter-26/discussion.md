# iter-26 proposal 監査コメント

## Web 検索
- 検索なし（理由: 提案は「差異の重要度分類」「比較単位の切替」という一般原則の範囲で自己完結しており、特定研究や固有用語への強い依拠がない）

## 総評
提案の狙い自体は理解できる。差異を一律に扱わず、比較粒度を切り替えるという発想は Objective.md の Exploration Framework ではカテゴリ C「比較の枠組みを変える」に素直に属しており、README.md / docs/design.md の研究コア（前提・探索・トレース・反証）も表面上は維持している。

ただし、今回の具体案は Compare checklist の既存 1 行を「差異分類→CONTRACT/CONTROL-FLOW のみ test-trace 必須」に置換しており、実効上は INTERNAL と分類された差異の反証密度を下げる。これは偽 NOT_EQUIV を減らす方向には働きうる一方、偽 EQUIV を増やす逆作用が比較的はっきり見えている。したがって、このままでは compare の改善というより判定重みの片寄りに近い。

## 1. 既存研究との整合性
- README.md と docs/design.md が強調する研究コアは「per-item tracing」「mandatory refutation」「unsupported claims を防ぐ certificate」であり、既存の Compare は「差異を見つけたら少なくとも1本は relevant test を差分経路で追う」という形で、そのコアを具体化している。
- 今回案は分類を導入する点ではコアと矛盾しないが、「INTERNAL なら test-tracing requirement を外せる」と読めるため、Guardrail #4 / Compare checklist の既存の安全装置を弱める方向がある。研究コアの“維持”には見えても、“強化”ではない。

## 2. Exploration Framework のカテゴリ選定
- 判定: 適切
- 理由: 提案の中心は「差異を見つけた後の比較単位をどう切り替えるか」であり、探索順序の変更でも、証拠取得法の変更でもなく、Objective.md のカテゴリ C「比較の枠組みを変える」に一致する。
- ただし注意点として、カテゴリ C の提案でも compare の decision point を変える際に反証義務を弱めると、カテゴリ D 的な“自己監査ゲート改変”に近い副作用を持つ。今回案はその境界に少し触れている。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
- EQUIVALENT 側への作用:
  - INTERNAL と見なした差異について test-trace を省略しやすくなるため、「差異はあるがテスト結果は同じ」と早く言いやすくなる。
  - よって偽 NOT_EQUIV の抑制には効きうる。
- NOT_EQUIVALENT 側への作用:
  - CONTRACT / CONTROL-FLOW に分類できた差異では、従来通り test-trace を要求するので、明確な反例提示は維持される。
  - ただし、実際には観測可能差異につながるものを INTERNAL と誤分類した場合、NOT_EQUIV に必要な追跡が起動せず、偽 EQUIV を増やしうる。
- 実効差分の評価:
  - 変更前は「semantic difference を見つけたら relevant test を最低1本追う」なので、差異の型に依らず一度は観測側へ落とす。
  - 変更後は「分類次第で観測側へ落とさない選択肢」が生まれる。これは双方向改善ではなく、主に“差異の過大評価を減らす代わりに差異の過小評価を許しやすくする”変更。

## 4. failed-approaches.md との照合
- 「探索経路の半固定」: NO
  - 差異発見後の分岐は増えるが、読み始めの順序や探索入口を半固定してはいない。
- 「必須ゲート増」: NO
  - 1 行置換であり、新しい必須欄やメタ判断欄は増やしていない。
- 「証拠種類の事前固定」: YES 寄り
  - 原因文言: `classify it as CONTRACT / CONTROL-FLOW / INTERNAL; test-trace the differing path for CONTRACT or CONTROL-FLOW before concluding “no impact”`
  - 問題は、差異発見後の証拠要求をカテゴリごとに事前配分しており、INTERNAL では test-trace を不要化している点。これは failed-approaches.md の「次に探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」に部分的に触れる。
- 追加所見:
  - 「既存の判定基準を、特定の観測境界だけに過度に還元しすぎない」にもやや接近している。理由は、分類のうち CONTRACT / CONTROL-FLOW だけを observable outcome へ直結すると定義し、INTERNAL から観測差異へ至る経路をテンプレ上で弱く扱うため。

## 5. 汎化性チェック
- 固有識別子チェック: 問題なし
  - proposal 中に具体的な数値 ID、リポジトリ名、テスト名、コード断片、ベンチマーク固有ケースの引用は見当たらない。
- 暗黙のドメイン前提:
  - `契約/制御/内部` の三分類は言語横断で一応通用する。
  - ただし `キャッシュ` を INTERNAL の例に入れているのはやや危うい。キャッシュは観測可能なタイミング差・例外・状態遷移に波及しうるため、「単なる内部差」と読ませると特定実装文化に寄る。
- 総合:
  - R1 的な露骨な overfit ではないが、カテゴリ名の定義次第では「内部差は軽い」という暗黙バイアスを持ちやすい。

## 6. 全体の推論品質への期待効果
- 期待できる点:
  - 些末な内部表現差を見つけた瞬間に NOT_EQUIV へ倒れる粗い比較を減らし、差異の重要度に応じて判断粒度を変える発想自体は有益。
  - 比較時の着眼点を「差異の存在」から「差異がどの層に効くか」へ移すので、推論の整理には寄与しうる。
- ただし現案のままでは:
  - “整理”は増えるが、“反証の質”は INTERNAL 枝で下がる。
  - compare の意思決定をより正確にするというより、特定枝で早く EQUIV に寄せる設計になっている。

## 停滞診断（必須）
- 懸念 1 点:
  - 監査 rubric には刺さりやすい（汎用・小変更・カテゴリ C）一方で、compare の実意思決定では「INTERNAL なら追わなくてよい」という説明強化に寄っており、判定改善より“省略の正当化”になっている懸念がある。
- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: YES
    - 原因文言: `only require test-tracing for CONTRACT or CONTROL-FLOW`

## compare 影響の実効性チェック（必須）
- 1) Decision-point delta:
  - Before/After が IF/THEN 2 行になっているか: YES
  - ただし条件と行動は実質「semantic difference を見つけたら扱う」で共通しており、差は“理由”だけではなく `INTERNAL では追跡不要` という分岐追加にある。ここは decision-point にはなっている。
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES
- 2) Failure-mode target:
  - 目標: 両方と書いているが、実効上は主に偽 NOT_EQUIV 低減。
  - メカニズム: 内部差を軽く扱うことで差異過大視を抑える一方、内部→観測差異の見落としで偽 EQUIV が増える危険がある。
- 3) Non-goal:
  - 反証手順や structural triage を置換しない、と明記されている点はよい。
  - ただし compare 実装上は INTERNAL 枝で test-trace obligation が弱まるため、「証拠種類の事前固定を避ける」という境界条件はまだ守り切れていない。
- Discriminative probe:
  - 抽象例: 2 つの変更が同じ外部 API を保つが、一方だけ内部キャッシュの更新条件を変えており、特定既存テストでは 2 回目呼び出し時の例外有無が変わるケース。
  - 変更前は semantic difference を見つけた時点で relevant test を差分経路へ落とすため、既存テストへの波及を確認しやすい。変更後はこれを INTERNAL と誤って軽く扱うと EQUIV 誤判定が起きやすい。
- 支払い（必須ゲート総量不変）の A/B 対応付けが proposal 内で明示されているか:
  - YES
  - 既存 1 行を新 1 行へ置換すると明記されている。

## 最大のブロッカー
- 片方向最適化が強いこと。
- 具体的には、`INTERNAL` と分類された差異で test-tracing requirement を外すため、偽 NOT_EQUIV を減らす代わりに偽 EQUIV を増やす逆方向悪化が明白で、proposal 内に回避策がない。

## 修正指示（2〜3点）
1. `only require test-tracing for CONTRACT or CONTROL-FLOW` を削り、置換先は「分類は優先順位付けのために使うが、semantic difference を no impact と結論する前の最低1本の relevant test-trace 義務は全カテゴリで維持」とすること。
2. 追加ではなく置換で済ませること。今の 1 行置換という“支払い”は維持しつつ、分類の役割を「どの test / path を先に追うかの優先順位」に限定し、「どのカテゴリなら追わなくてよいか」の判定ゲートにしないこと。
3. `INTERNAL` の例示から `cache` を外すか、「内部差でも観測可能条件に接続しうる場合は CONTRACT/CONTROL-FLOW 同様に追う」と明記して、内部差の過小評価バイアスを下げること。

## 結論
承認: NO（理由: focus_domain の片方向最適化で逆方向の悪化が明白。INTERNAL 分類時に test-trace 義務を外すため、偽 EQUIV の回避策が不足している）
