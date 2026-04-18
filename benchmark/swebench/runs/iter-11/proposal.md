1) Target misclassification: 両方（偽 EQUIV / 偽 NOT_EQUIV）
2) Current failure story (抽象): 「反証が見つからない」ことを根拠に結論へ急ぎ、結論を支える“決定的な主張（hinge）”が UNVERIFIED のままでも EQUIV/NOT_EQUIV を断定してしまう。
3) Mechanism (抽象): 結論直前に localize/explain 的に「判定を反転させうる hinge を 1 つだけ同定し、それが VERIFIED か（または test assertion まで接続できるか）」を明示させることで、見落とし・過剰反応の両方を減らす。
4) Non-goal boundary: 読解順序の半固定・証拠種類の事前固定・新しい必須ゲート（総量）の増設はしない（既存チェックの置換/統合で支払う）。

---

Exploration Framework category: F（原論文の未活用アイデアを導入）
- 選んだメカニズム: 「localize/explain の compare 応用」＋「エラー分析知見（UNVERIFIED/推測が結論に混入する失敗）」の最小導入。
- 理由: SKILL.md の compare は“反証の提示/不在証明”に強い一方で、その反証探索自体が UNVERIFIED な hinge に依存しているケースで結論が出やすい。localize/explain 的に hinge を 1 つだけ明示して VERIFIED かどうかで分岐させると、探索経路や証拠種類を固定せずに意思決定だけを改善できる。

改善仮説（1つ）
- compare で EQUIV/NOT_EQUIV を主張する直前に「判定を反転させうる hinge（最小の決定点）」を 1 つだけ言語化し、それが VERIFIED（または diverging assertion まで接続済み）でない限り結論を保留して追加探索するようにすると、推測混入による偽 EQUIV と、未接続差分の過剰反応による偽 NOT_EQUIV の両方が減る。

現状ボトルネック診断（該当箇所の短い引用 + 失敗メカニズム）
- 引用（Compare checklist）:
  - "Provide a counterexample (if different) or justify no counterexample exists (if equivalent)"
- 誘発する失敗メカニズム:
  - 反証/不在証明の形式を満たすことが“結論の十分性”の代理になりやすく、結論の hinge が UNVERIFIED（例: 第三者ライブラリ推測、未読の分岐、未接続の assertion）でも、追加探索より先に結論が出る。

---

Decision-point delta（IF/THEN、2行・分岐可能な観測条件）
- Before: IF "no counterexample exists" セクションを埋められており、差分が assertion までの VERIFIED な hinge に落ちていなくても THEN 結論を出す because "反証が見つからない/見つかった" という根拠型で十分だと扱ってしまう。
- After:  IF 結論 hinge が UNVERIFIED（Step 4 の trace table で UNVERIFIED が残る、または NOT_EQ の diverging assertion に接続できない） THEN 結論を保留して追加で探す because "hinge を VERIFIED に落とす／接続する" という根拠型が満たされるまで断定しない。
- 対応する SKILL.md の見出し/セクション:
  - "## Compare" → "### Compare checklist"
  - （観測条件の根拠）"### Step 4: Interprocedural tracing" の VERIFIED/UNVERIFIED

Trigger line:
- "- Trigger: if the verdict hinges on any UNVERIFIED step (or a semantic diff not linked to a diverging assertion), HOLD conclusion and continue exploring until the hinge is VERIFIED."

---

変更タイプ: 定義の精緻化（compare の意思決定ポイントを、localize/explain 的な hinge 概念で最小限だけ具体化）
- なぜ効くか: 「反証がない」=「断定してよい」ではない、というエラー分析の要点を、結論直前の分岐条件（UNVERIFIED hinge の有無）として一行に落とすことで、結論の出し方そのものが変わる。

SKILL.md のどこをどう変えるか（具体）
- "### Compare checklist" の末尾付近を、(a) 冗長な項目 1 行削除、(b) 既存の最後の項目を hinge トリガ付きに置換。

支払い（必須ゲート総量不変の証明）
- 強める: "Provide a counterexample..." を "Trigger: hinge が UNVERIFIED なら結論保留→追加探索" に置換（結論トリガを明確化）
- 支払う: 冗長な "Identify changed files for both sides" を削除（"Structural triage first" とテンプレート内 S1/S2 と重複）

---

変更差分の最小プレビュー（同じ引用範囲、3〜10行）
Before（SKILL.md 自己引用）:
```text
### Compare checklist
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing
- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```

After（同じ範囲の想定差分）:
```text
### Compare checklist
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing
- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- Trigger: if the verdict hinges on any UNVERIFIED step (or a semantic diff not linked to a diverging assertion), HOLD conclusion and continue exploring until the hinge is VERIFIED.
```

意思決定ポイント（結論/保留/追加探索）の変化（1行）
- 変更前は「反証がない/ある」を埋められると結論へ進みやすいが、変更後は hinge が UNVERIFIED なら結論を保留し、VERIFIED になるまで追加探索へ分岐する。

---

期待される挙動差（compare に効く形）
- 変更前に起きがちな誤り（一般形）:
  - 偽 EQUIV: 反証探索の“不在”を示したつもりでも、実際は UNVERIFIED な前提（外部 API/未読分岐/暗黙仕様）に依存しており、潜在的な反例を見落として EQUIV を断定する。
  - 偽 NOT_EQUIV: 差分自体は見つけたが、テストの diverging assertion まで接続できていないのに NOT_EQUIV を断定する（差分の重要度を過大評価）。
- 変更後に減るメカニズム（1つ）:
  - localize/explain 的に hinge を 1 つに絞って VERIFIED/接続性を分岐条件にすることで、断定に必要な最小証拠が欠けているときは「結論」ではなく「追加探索」へ行動が変わる。
- どちらの誤判定が減る見込みか（片方向最適化にしない）:
  - UNVERIFIED hinge を検知して保留→探索へ回すため、偽 EQUIV を直接抑制。
  - 同時に「assertion へ未接続の差分」を hinge 不成立として保留にするため、偽 NOT_EQUIV も抑制（断定を遅らせ、接続できないなら差分の重要度を再評価する流れになる）。

---

最小インパクト検証（思考実験）
- ミニケース A（変更前は誤りやすく、変更後は安定）:
  - 反例の形は思い描けるが、途中に外部/未読の挙動があり、実際に反例が成立するかが UNVERIFIED のまま「NO COUNTEREXAMPLE EXISTS」を書いて EQUIV に寄ってしまう状況。
  - After では UNVERIFIED hinge がトリガになり、結論を保留して追加探索（同じ系の使用箇所・型/契約・分岐条件など）へ分岐する。
- ミニケース B（逆方向の誤判定を誘発しうる状況 + 悪化しない理由/回避策）:
  - すべてを VERIFIED にしようとして探索が長引き、判断が萎縮して結論が出ないリスク。
  - 回避: hinge を「1つだけ」に localize する（複数の未検証を全部潰すのではなく、判定を反転させる最小点だけを優先して VERIFIED 化する）。これは新しい必須手順の増設ではなく、既存探索の優先度づけ（局所化）として働く。

focus_domain トレードオフ（overall）
- 悪化しうる経路（想定）: UNVERIFIED の検知が広すぎると、EQUIV でも保留が多発し探索が増える（過度な保守化）。
- 避ける工夫（新しい必須手順を増やさずに）: トリガ条件を「hinges on」に限定し、UNVERIFIED が存在しても判定に無関係なら保留しない（“全部 VERIFIED” を要求しない）。

---

failed-approaches.md との照合（整合点を具体に 1〜2 点）
- 「証拠種類をテンプレで事前固定しすぎる変更は避ける」: 本提案は“どの証拠を探すか”を固定せず、観測可能な状態（UNVERIFIED hinge の有無）で分岐するだけ。
- 「読解順序の半固定は避ける」: hinge を 1 つに絞るのは“入口の固定”ではなく“結論直前の十分性判定”の局所化であり、読む順序や探索経路を指定しない。

未参照（理由）
- README.md: 今回は design.md で論文→スキル翻訳とエラー分析の要点が確認でき、追加の正当化に必須ではないため未参照。
- docs/reference/agentic-code-reasoning.pdf: design.md が Appendix/失敗分析の要約を提供しており、5行以内 diff の小変更の根拠として十分なため未参照（停滞対策として参照コストを節約）。
- docs/design.md: 参照（localize/explain の存在、エラー分析の失敗パターンの根拠づけ）。
- README.md / docs/reference は、監査で根拠不足と判断された場合にのみ次回参照で補う。

変更規模の宣言
- 追加: 1 行
- 置換: 1 行（既存チェックリスト項目の置換）
- 削除: 1 行（冗長チェックリスト項目）
- 合計追加行: 1（hard limit 5 以内）

---

停滞対策の自己チェック
- 単なる整形/美文化に留まっていないか？: 留まっていない。UNVERIFIED hinge の有無で「結論 vs 追加探索」が分岐し、compare の意思決定が変わる。
- compare の誤判定を減らす“意思決定ポイント”が実際に変わるか？: 変わる。結論直前に hinge を VERIFIED に落とせない場合は結論を保留する。
- Decision-point delta が理由の言い換えだけになっていないか？: なっていない。Before/After で行動（結論を出す vs 保留して追加探索）が変わる。
- 必須ゲート総量を増やしていないか？: 増やしていない。チェックリスト項目を置換し、冗長 1 行を削除して支払っている。