過去提案との差異: これは STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭める案ではなく、結論直前の弱い環の自己点検と CONFIDENCE/UNVERIFIED の出し分けを変える案である。
Target: 両方
Mechanism (抽象): verdict-critical な最弱リンクを明示し、その検証状態で最終結論の CONFIDENCE と UNVERIFIED 明示を分岐させる。
Non-goal: 構造差を特定の観測境界へ写像して早期 NOT_EQUIV 条件を作り直すことはしない。

カテゴリ D 内での具体的メカニズム選択理由:
- 候補1: Step 5.5 の UNVERIFIED 扱い。現在は「UNVERIFIED でも結論不変と言い切れば進める」に寄りやすく、変更後は CONFIDENCE/UNVERIFIED 明示/追加探索が変わる。
- 候補2: D2 の pass-to-pass relevance 未解決時の provisional relevance。現在は保留寄りに流れやすいが、変更後アウトカム差を明快に作りにくいので不採用。
- 候補3: STRUCTURAL TRIAGE からの早期 NOT_EQUIV。挙動差は大きいが直近却下案と機構が近すぎるので不採用。
- 選定理由は 2 点だけ: (1) compare の実行時アウトカムとして CONFIDENCE/UNVERIFIED/追加探索を直接変えられる、(2) 構造差ゲートではなく既存の自己チェック分岐を置換するので禁止方向を踏まない。

改善仮説:
結論を支える最弱の verdict-critical link を明示させると、片側だけ追跡が強く他側が未検証なままの過信を抑え、偽 EQUIV と偽 NOT_EQUIV の両方を減らせる。

該当箇所と変更:
- Step 5.5: "Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion."
- Step 6: "Assigns a confidence level: HIGH / MEDIUM / LOW"
これを、行単位の UNVERIFIED 表示から「verdict-critical な最弱リンクを特定し、その状態が最終結論をどう制約するか」を書く分岐へ置換する。

Decision-point delta:
Before: IF trace table の各行に VERIFIED/UNVERIFIED 表示があり、UNVERIFIED を「結論不変」と言語化できる THEN そのまま verdict を出しうる because 行ごとの記帳充足を根拠にする。
After:  IF verdict-critical な最弱リンクが UNVERIFIED または片側だけしか decisive path が VERIFIED でない THEN HIGH を禁止し、その弱い環を結論中で明示するか targeted exploration を続ける because verdict を支える最弱環の強度を根拠にする。

Payment: add MUST("Name the weakest verdict-critical link; if it is UNVERIFIED or verified on only one side, either resolve it or cap the conclusion to that uncertainty.") ↔ demote/remove MUST("Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion.")

変更差分プレビュー:
Before:
- [ ] Every function in the trace table is marked VERIFIED, or explicitly UNVERIFIED with a stated assumption that does not alter the conclusion.
- Assigns a confidence level: HIGH / MEDIUM / LOW
After:
- [ ] Trigger line (planned): "Name the weakest verdict-critical link; if it is UNVERIFIED or verified on only one side, either resolve it or cap the conclusion to that uncertainty."
- Assigns a confidence level bounded by the weakest verdict-critical link; HIGH only if both sides' decisive path to the claimed same/different test outcome is VERIFIED.

Discriminative probe:
抽象ケース: Change A は assertion まで完全追跡でき、Change B は分岐を決める設定解決関数だけ UNVERIFIED のままでも、周辺の構造差が小さいため同じ outcome に見える。
変更前は「UNVERIFIED だが結論不変」と処理して偽 EQUIV か偽 NOT_EQUIV を高信頼で出しがちだが、変更後はその関数が weakest verdict-critical link として表面化し、MEDIUM 以下＋UNVERIFIED 明示またはその点への追加探索になる。

Runtime delta check:
変更前でも変更後でも同じ結論・同じ追加探索・同じ CONFIDENCE ならこの案は無効である。これは weakest verdict-critical link が露出した時に HIGH を落とすか、UNVERIFIED を明示するか、追加探索へ戻すかの少なくとも 1 つが変わるので無効ではない。

failed-approaches.md との照合:
- 原則2と整合: 未確定性を常に保留へ倒す新規 fallback ではなく、既存の必須自己チェックを verdict-critical link ベースに置換するだけである。
- 原則3と整合: 新しい抽象ラベルで差分昇格をゲートする案ではなく、既存の trace と conclusion の接続を自己点検する局所分岐であり、中間表現の必須化ではない。

変更規模の宣言:
置換は Step 5.5 の checklist 1 行と Step 6 の confidence 1 行が中心で、合計 4 行前後の差分に収まる。15 行以内。