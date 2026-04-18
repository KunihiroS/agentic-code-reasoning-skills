1) Target misclassification: 両方（偽 EQUIV / 偽 NOT_EQUIV）
2) Current failure story (抽象): 構造差（片側だけのファイル変更など）を見た瞬間に「関係あり」と早合点して NOT_EQUIV にショートカットしたり、逆に「関係なさそう」と早合点して EQUIV 側に寄せ、どちらも“関連テストとの接続が未検証”のまま誤判定しがち。
3) Mechanism (抽象): 構造トリアージのショートカットを「関連テストへの VERIFIED な接続」が観測できた場合にのみ発火させ、接続が UNVERIFIED のときは保留して分析を続けるため、過剰反応（偽 NOT_EQUIV）と見落とし（偽 EQUIV）を同時に減らす。
4) Non-goal boundary: 読解順序の半固定（“常にテストから読む”など）、証拠種類の事前固定、結論直前の必須ゲート増は行わない（ショートカット条件の明確化のみ）。

# Proposal (focus_domain: overall)

## Exploration Framework カテゴリ
- カテゴリ: A. 推論の順序・構造を変える
- 選んだ具体メカニズム: 「ショートカット結論（NOT_EQUIVALENT 直行）の発火条件を、先に“観測できる接続（VERIFIED/UNVERIFIED）”で分岐させる」
- 理由: compare は“結論を出す/保留する/追加で探す”の分岐が、(a) 早すぎる NOT_EQUIV ショートカット と (b) 根拠の薄い EQUIV の自己説得 の両方を生む。ここを「接続が VERIFIED か UNVERIFIED か」という観測可能状態で分岐させると、手順総量を増やさずに結論のタイミング（保留 vs 直行）だけを変えられる。

## 改善仮説（1つ）
構造差分を根拠に結論へショートカットする分岐を、「関連テストへの接続が VERIFIED のときだけ許可し、UNVERIFIED のときは ANALYSIS 継続に回す」ように順序づけると、構造差への過剰反応と、未検証のままの同一視の両方が減り、overall の推論品質が上がる。

## 現状ボトルネックの診断（SKILL.md 自己引用 + 誘発メカニズム 1つ）
該当箇所（Compare → Certificate template → STRUCTURAL TRIAGE 直後）:

> "If S1 or S2 reveals a clear structural gap (missing file, missing module
> update, missing test data), you may proceed directly to FORMAL CONCLUSION
> with NOT EQUIVALENT without completing the full ANALYSIS section."

誘発する失敗メカニズム:
- "clear structural gap" が観測可能条件として曖昧で、関連テストへの接続（import/call path 等）が未検証でも NOT_EQUIV 直行を正当化しうる。結果として、偽 NOT_EQUIV（関係ない差分への過剰反応）と、逆に“接続未検証”という不確実性を抱えたまま EQUIV 側へ自己説得する揺れ（偽 EQUIV）が出やすい。

## Decision-point delta（IF/THEN の2行・行動が変わる分岐）
対応セクション: Compare → Certificate template → "STRUCTURAL TRIAGE (required before detailed tracing)" 付近

- Before: IF "S1 or S2 reveals a clear structural gap" THEN 結論を出す（NOT EQUIVALENT に直行） because 構造差そのものを決定打として扱える（関連テストへの接続が未検証でも発火しうる）。
- After:  IF "S2 yields a VERIFIED relevance link to relevant tests" THEN 結論を出す（NOT EQUIVALENT に直行）; ELSE（relevance が UNVERIFIED）結論を保留して ANALYSIS を続ける because 決定打は“構造差”ではなく“関連テストとの接続が VERIFIED であること”になる。

Trigger line:
- "If relevance is UNVERIFIED, do not short-circuit: continue to ANALYSIS."

## 変更タイプ
- 変更タイプ: 定義の精緻化（ショートカット分岐条件の観測可能化） + 軽い並べ替え（ショートカット発火を VERIFIED/UNVERIFIED の後に置く）
- なぜ効くか: 追加の必須作業を増やさず、結論直行の“発火条件”を観測可能状態に落とすことで、比較器（compare）の行動差が確実に生まれる。

## SKILL.md のどこをどう変えるか（具体）
Compare → Certificate template の、STRUCTURAL TRIAGE の後にある「NOT EQUIVALENT 直行を許す」3行を置換し、
- VERIFIED な関連テスト接続がある場合のみ直行
- UNVERIFIED の場合は直行せず ANALYSIS 継続
を明示する。

## 支払い（必須ゲート総量不変の証明）
- 今回は MUST/REQUIRED の新設・強化を行わず、既存の "may proceed directly" の発火条件を明確化するだけなので、必須ゲート総量は増えない（支払い不要）。

## 変更差分の最小プレビュー（3〜10行、同一範囲の Before/After）
対象: Compare → Certificate template → STRUCTURAL TRIAGE の直後（ショートカット記述）

```diff
-If S1 or S2 reveals a clear structural gap (missing file, missing module
-update, missing test data), you may proceed directly to FORMAL CONCLUSION
-with NOT EQUIVALENT without completing the full ANALYSIS section.
+If S2 yields a VERIFIED relevance link to relevant tests (e.g., a relevant test imports/calls the missing file/module),
+you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section.
+If relevance is UNVERIFIED, do not short-circuit: continue to ANALYSIS.
```

意思決定ポイントの変化（1行）:
- NOT_EQUIV 直行のトリガが「曖昧な構造差」から「関連テストへの VERIFIED 接続」に変わり、UNVERIFIED のときは“結論を保留して追加で探す（ANALYSIS 継続）”に分岐する。

## 期待される挙動差（compare に効く形で）
- 変更前に起きがちな誤り（一般形）: 構造差を見て、関連テストへの接続が未検証でも NOT_EQUIV を即断（偽 NOT_EQUIV）／または接続未検証の不確実性を抱えたまま EQUIV を言い切る（偽 EQUIV）。
- 変更後に減るメカニズム: UNVERIFIED 状態ではショートカットが発火しないため、少なくとも ANALYSIS の中で“関連テストへの接続”を確認する方向に探索が続き、過剰反応もしにくく、同一視もしにくい。
- どちらの誤判定が減る見込みか（片方向最適化回避）: 主に偽 NOT_EQUIV を減らしつつ、UNVERIFIED のまま EQUIV を言い切る経路も抑制するため、偽 EQUIV も同時に減る（ただし EQUIV を出すための根拠が薄い場合は CONFIDENCE が下がる方向に働く）。

## 最小インパクト検証（思考実験）
- ミニケース A（変更前は揺れる/誤る→変更後は安定）:
  - 状況: 片側にだけ“追加のファイル変更”があるが、それが関連テストの import/call path に入っているかが未確認。
  - Before: "clear structural gap" で NOT_EQUIV 直行しやすい。
  - After: relevance が UNVERIFIED なので直行せず ANALYSIS 継続 → 接続がないなら過剰反応せず、接続があるなら VERIFIED になった時点で NOT_EQUIV 直行できる。

- ミニケース B（逆方向の誤判定を誘発しうる状況 + 回避）:
  - 悪化しうる経路: UNVERIFIED を理由に ANALYSIS を続けた結果、結論を保留しすぎて EQUIV/NOT_EQUIV の決断が遅れ、曖昧な LOW confidence が増える。
  - 回避策（新しい必須手順は増やさない）: 本提案は「ショートカットの条件」を変えるだけで、従来どおり ANALYSIS→FORMAL CONCLUSION の経路自体は維持される。UNVERIFIED の扱いは Core Method の Step 4/5.5（UNVERIFIED 明示と結論範囲の制限）で吸収し、結論形式（YES/NO + CONFIDENCE）は維持したまま“直行するか/続けるか”だけを切り替える。

## focus_domain トレードオフ（overall でも明示）
- 想定する悪化経路: UNVERIFIED を過度に重く扱い、NOT_EQUIV 直行を控えすぎて（保留しすぎて）判断が萎縮する。
- 避ける工夫: 「UNVERIFIED なら常に結論保留」という新ゲート化はしない。あくまで“NOT_EQUIV 直行ショートカット”だけを UNVERIFIED で止め、通常の ANALYSIS→FORMAL CONCLUSION は従来どおり進められる（= 必須ゲート総量を増やさない）。

## failed-approaches.md との整合（1〜2点、具体）
- 「読解順序の半固定は避ける」（failed-approaches.md 14–18 行目）に対し: 本変更は“常にテストから読む/常にこの証拠を探す”を強制しない。あくまでショートカット発火条件を VERIFIED/UNVERIFIED という状態で分岐させ、探索経路の自由度は維持する。
- 「結論直前の新しい必須メタ判断を増やしすぎない」（25–29 行目）に対し: 新しい必須チェック項目を追加せず、既存の "may proceed directly" の曖昧さを減らすだけで、結論前ゲート総量を増やさない。

## 変更規模の宣言
- SKILL.md 変更は 3 行の置換のみ（5 行以内）。新セクション追加なし。新しい MUST/REQUIRED なし。

## 今回未参照の資料
- README.md / docs/design.md / docs/reference/agentic-code-reasoning.pdf は未参照（理由: 今回の提案は compare テンプレート内の“ショートカット分岐条件”の観測可能化という局所変更で、研究コア構造の追加正当化が不要なため。Objective.md のカテゴリ定義と failed-approaches.md の再演回避だけ参照すれば足りる）。

## 停滞対策の自己チェック（明記）
- 監査で褒められやすい整形だけで終わっていないか？: いいえ。"NOT_EQUIV 直行" の発火条件が変わり、UNVERIFIED では ANALYSIS 継続へ分岐するため、compare の行動が変わる。
- compare の誤判定を減らす意思決定ポイントが実際に変わるか？: はい。結論を出す/保留するの分岐（ショートカット可否）が、観測可能条件（VERIFIED/UNVERIFIED）で切り替わる。
- Decision-point delta が理由の言い換えだけになっていないか？: なっていない。Before は "clear structural gap" で直行、After は "VERIFIED relevance link" で直行、UNVERIFIED は直行せず継続、で条件と行動が変わる。
- 必須ゲート総量を増やしていないか？: 増やしていない。新しい MUST/REQUIRED や新チェックリスト項目は追加せず、既存の直行条件を絞り込むだけ。