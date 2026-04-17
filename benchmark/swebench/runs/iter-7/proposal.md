1) Target misclassification: 偽 EQUIV を減らす
2) Current failure story (抽象): 「一度も“結論をひっくり返し得る反例像”を狙わずに、形式的に“何か検索した”だけで EQUIV を確定してしまい、間接的に影響する既存テスト/オラクル可視差分を取り逃がす」
3) Mechanism (抽象): 探索ログと自己チェックの中で、検索/追跡を“情報量”ではなく“結論を反転させ得る反例形”に寄せることで、決定を誤らせる未探索領域が見落とされにくくなる
4) Non-goal boundary: 読解順序の半固定・証拠種類の事前固定・結論前の必須ゲート増（チェック項目の増設）はしない

---

Exploration Framework のカテゴリ: B（情報の取得方法を改善する）
- メカニズム選択理由: 現行は「探索は固定順序ではない」「少なくとも1回検索する」までは書けている一方で、“何を探すべきか”ではなく“どう探すべきか（結論を反転させ得る探索＝反例形）”が曖昧なため、検索が意思決定を変えない儀式化（checkbox 充足）になりやすい。カテゴリBの「どう探すか」を、探索の自由度を落とさずに定義精緻化で補う。

改善仮説（1つ）
- 「検索/追跡の合格条件」を“何かを探した”から“結論を反転させ得る反例形を狙った”へ寄せるだけで、EQUIV の誤確定（未探索の反例が実は存在するのに ‘探したつもり’ で終える）が減る。

現状ボトルネックの診断（SKILL.md 自己引用 + 失敗メカニズム）
- 該当箇所（Core Method / Step 5.5）:
  - 現状は「少なくとも1回 actual file search/inspection」を満たせば良く、探索が“結論を覆し得る反例探索”になっていなくても通ってしまう。
  - その結果、compare で EQUIV を主張する場面でも、決定境界（EQUIV↔NOT EQUIV）を動かし得る探索が起きず、偽 EQUIV が残る。

Decision-point delta（IF/THEN 2行、行動差のみ）
- Before: IF 「最低1回の検索/inspection をした」かつ「手元の追跡で両者が同じに見える」 THEN EQUIV を結論しがち because 根拠の型が『チェックリスト充足 + 既知経路の整合』に寄っている
- After:  IF 「結論を反転させ得る反例形（counterexample-shaped）を具体化し、それを狙う検索/inspection が未実施」 THEN 結論を保留して追加で探す because 根拠の型を『決定境界を動かし得る探索の有無』に切り替える
- 対応する SKILL.md の見出し/セクション名:
  - "Core Method" → "Step 3: Hypothesis-driven exploration"
  - "Core Method" → "Step 5.5: Pre-conclusion self-check (required)"

変更タイプ: 定義の精緻化
- なぜ効くか: 「検索したかどうか」ではなく「“結論を覆す形”を狙った検索か」を定義として明確化すると、探索の自由度（どこを読む/何を探す）は固定せずに、探索行動だけを“意思決定に効く方向”へ寄せられる。

SKILL.md のどこをどう変えるか（具体）
- Step 3 の探索ログ内の optional 欄を、汎用の INFO GAIN から “結論反転（decision flip）ターゲット”へ置換して、次アクション選択を「不確実性の解像」だけでなく「決定境界を動かす証拠」へ寄せる。
- Step 5.5 の必須チェック項目（既存）を1行だけ定義精緻化し、「何か検索」ではなく「counterexample-shaped（結論を覆す形）を狙った検索/inspection」を要求する。
  - 注意: チェック項目の“追加”はせず、既存項目の意味だけを置換する（必須ゲート総量は増やさない）。

変更差分の最小プレビュー（自己引用 3〜10行 / Before→After、同一範囲）
(1) Core Method / Step 3: Hypothesis-driven exploration
```
NEXT ACTION RATIONALE: [why the next file or step is justified]
OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]
```
After:
```
NEXT ACTION RATIONALE: [why the next file or step is justified]
OPTIONAL — DECISION-FLIP TARGET: [what evidence would most likely flip the current leading conclusion; what observation would change your next action]
```
- 意思決定ポイントの変化（1行）: 「次に何を追加で探すか」が “不確実性一般” から “EQUIV/NOT EQUIV の境界を動かす探索” へ寄る

(2) Core Method / Step 5.5: Pre-conclusion self-check (required)
```
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least one actual file search or code inspection — not reasoning alone.
```
After:
```
- [ ] The Step 5 refutation or alternative-hypothesis check involved at least one counterexample-shaped search/inspection (i.e., a concrete “would flip the conclusion” pattern) — not reasoning alone.
```
- 意思決定ポイントの変化（1行）: EQUIV を結論する条件が「何か検索した」から「結論反転し得る反例形を狙って検索した」へ変わり、未探索なら保留/追加探索に倒れる

期待される "挙動差"（compare に効く形）
- 変更前に起きがちな誤り（一般形）:
  - 既知の差分が小さい／追跡した経路が一致しているときに、形式的な検索を1回行っただけで EQUIV を確定し、実際には別経路の既存テストが観測し得る差分（オラクル可視）を見落として偽 EQUIV になる。
- 変更後にその誤りが減るメカニズム（1つ）:
  - “結論をひっくり返すにはどんな反例（テスト×観測差分）が必要か”を先に具体化し、それに一致する探索を行うまで EQUIV を確定しにくくなるため、探索が意思決定に直結する。
- 誤判定が減る見込み（片方向最適化にならない書き方）:
  - 主に 偽 EQUIV を減らす。あわせて、反例形が見つからないときでも「反例形を狙った探索をした」という根拠が残るため、根拠薄い NOT EQUIV への飛躍（偽 NOT_EQUIV）を“自信度/保留”で吸収しやすく、逆方向の悪化を抑える。

最小インパクト検証（思考実験で可、抽象）
- ミニケース A（変更前は判断が揺れる/誤るが、変更後は安定）:
  - 2実装が主要経路では同じに見えるが、別の既存テストが“例外種別/戻り値の境界値/外部状態更新”のどれかを観測し得る（＝オラクル可視）差分が潜む状況。
  - 変更前: 「1回検索した」だけで EQUIV に寄りやすい。
  - 変更後: 反例形（どの観測差分が出たら NOT EQUIV か）を立て、それを狙った探索が未実施なら保留→追加探索に倒れるため、偽 EQUIV が減る。
- ミニケース B（逆方向の誤判定を誘発しうる状況 + 回避）:
  - 2実装が本当に等価だが、反例形の言語化が難しく、探索が過剰に長引いて「結論が出ない/保守的に NOT EQUIV と言ってしまう」リスクがある状況。
  - 回避: 本変更は“必須の探索量増”ではなく「検索の形（decision-flip）」の定義精緻化なので、反例形は1つの具体例で十分（網羅不要）。反例形を1つ立ててそれに対応する軽量探索を行ったなら、見つからないこと自体を“結論支持の証拠”として扱える（保留に固定しない）。

focus_domain トレードオフ（overall のため、悪化しうる経路を1つ想定 + 回避策）
- 悪化しうる経路: 「counterexample-shaped を強く意識しすぎて、常に“反例探し”へ偏り、十分に等価である状況でも結論が遅れて保留が増える」
- 回避策（新しい必須手順を増やさずに）:
  - Step 3 側は OPTIONAL 欄の置換に留め、探索経路の自由度を維持する。
  - Step 5.5 側も“1つの反例形に対応する軽量探索”を満たせばよい定義に留まり、網羅探索を要求しない（追加ゲート増設をしない）。

failed-approaches.md との照合（1〜2点、具体）
- 「証拠の種類をテンプレートで事前固定しすぎる変更は避ける」（failed-approaches.md 8-10行目）に整合: 本変更は“何を探すか（証拠種類）”を固定せず、“結論を覆す形かどうか”という探索の型（どう探すか）だけを定義する。
- 「読解順序の半固定は避ける」（failed-approaches.md 11-15行目）に整合: どこから読むか・何を先に確定するかは指定しない。決定境界を動かす探索を“次アクション選択の評価軸”として追加するだけ。

変更規模の宣言
- SKILL.md の変更は 2 行の置換のみ（5行以内、必須ゲート総量の増加なし）

停滞対策の自己チェック（proposal 内で明記）
- 監査で褒められやすいだけの整形/美文化に留まっていないか？
  - 留まっていない。検索/探索の“合格条件”を変えるため、EQUIV を結論する条件が実際に変わる。
- compare の誤判定（偽 EQUIV / 偽 NOT_EQUIV）を減らす意思決定ポイントが実際に変わるか？
  - 変わる。EQUIV を出す前提が「何か検索した」から「結論反転し得る反例形を狙った検索」に変わり、未実施なら保留/追加探索へ分岐する。
- Decision-point delta の Before/After が「条件も行動も同じで、理由だけ言い換え」になっていないか？
  - なっていない。After は “counterexample-shaped が未実施” という条件で行動（保留→追加探索）が変わる。
- 必須ゲートに手を入れるなら置換/統合/削除で総量を増やしていないか？
  - 増やしていない。Step 5.5 の既存チェック項目を1行置換するだけで、項目追加はない。
