# Iter-4 Proposal (focus_domain: overall)

## Exploration Framework
- カテゴリ: E. 表現・フォーマットを改善する（強制）
- このカテゴリ内で選ぶメカニズム: 「曖昧文言の具体化（意思決定条件の精緻化）」
  - 理由: compare で最も致命的なのは「どの根拠で結論を出してよいか」が曖昧なまま結論へショートカットすること。手順や必須ゲートの追加ではなく、“結論へ進んでよい条件”の言い回しを具体化して、同じ手順のまま誤判定を減らす。

## 改善仮説（1つ）
「早期に NOT EQUIVALENT を確定してよい条件」を ‘関連テストのスコープ（D1/D2）と結びつけて明確化すると、構造差（ファイル差）を過大評価した premature 結論が減り、EQUIV/NOT_EQUIV の両方向の誤判定が減る。

## 現状ボトルネック診断（SKILL.md から短く引用 + 失敗メカニズム1つ）
該当箇所（compare の STRUCTURAL TRIAGE の早期結論条件）:

> If S1 or S2 reveals a clear structural gap (missing file, missing module
> update, missing test data), you may proceed directly to FORMAL CONCLUSION
> with NOT EQUIVALENT without completing the full ANALYSIS section.

誘発する失敗メカニズム（1つ）:
- 「clear structural gap」が曖昧で、‘差がある’ という事実だけで ‘テスト結果（D1）に影響する差’ だと誤って短絡しやすい。その結果、実際には D2 の relevant tests に無関係な構造差でも NOT_EQUIV を宣言する（偽 NOT_EQUIV）経路が生まれる。

## 変更タイプ
- 変更タイプ: 定義の精緻化（曖昧条件の具体化）
- なぜ効くか: 追加の調査手順を増やさず、同じ STRUCTURAL TRIAGE を行う前提のまま「結論へ進む条件」を “D1/D2 のスコープに必ず関係する” へ寄せることで、意思決定ポイント（ショートカットの可否）が安定する。

## SKILL.md のどこをどう変えるか（具体）
- Compare → Certificate template → STRUCTURAL TRIAGE 直後の「早期に NOT EQUIVALENT へ進める」条件文を、
  - 現状の「clear structural gap」
  - 変更後の「D1/D2 の relevant tests スコープに対して、影響が必然/証明可能な structural gap（例: relevant test が import/load/execute するファイル/モジュール/テストデータの欠落）」
  へ言い換える。
- 目的: “構造差” それ自体ではなく “テスト結果（D1）へ必ず効く構造差” のときだけ早期に NOT_EQUIV を確定できる、と読めるようにする。

## 変更差分の最小プレビュー（必須: 同一範囲を3〜10行で Before/After）
対象範囲（同じ3行）:

Before:
```text
If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```

After:
```text
If S1 or S2 reveals a clear structural gap that necessarily affects D1 under
D2’s relevant-test scope (e.g., omitted file/module/test data that a relevant
test imports/loads/executes), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```

意思決定ポイントがどう変わるか（1行）:
- Before は「差が見える」だけで早期 NOT_EQUIV に寄りやすいが、After は「その差が D1/D2 のスコープで必然的に効く」場合にのみ早期 NOT_EQUIV へ進む、に変わる。

## 期待される “挙動差” の説明（compare に効く形）
- 変更前に起きがちな誤り（一般形）:
  - “片方にだけ存在する変更ファイル/データ” を見つけた時点で、それが relevant tests に触れない可能性を無視して NOT_EQUIV を宣言してしまう（偽 NOT_EQUIV）。
- 変更後にその誤りが減るメカニズム（1つ）:
  - 「早期 NOT_EQUIV の正当化」を “D1（テスト結果同一性）” と “D2（relevant tests の範囲）” に明示的に紐づけるため、構造差が ‘スコープ外の差’ である限り、ショートカット結論にブレーキがかかる（同じ手順量のまま、判断の条件だけが明確化される）。
- どちらの誤判定が減る見込みか（片方向最適化にならない形で）:
  - 主に偽 NOT_EQUIV を減らす見込み。
  - 同時に、偽 EQUIV を増やしにくい（“影響が必然” な structural gap は依然として早期 NOT_EQUIV を許容するため、重要な差を見逃して EQUIV に倒れる方向には働きにくい）。

## 最小インパクト検証（思考実験で可）
- ミニケース A（変更前は揺れる/誤るが、変更後は安定する抽象状況）:
  - 2つの変更のうち片方だけが追加の補助ファイル/補助データを含むが、それは runtime/test の import/load 経路に乗らず、観測可能な出力にも影響しない状況。
  - Before: “clear structural gap” だけで NOT_EQUIV を宣言しやすい。
  - After: “relevant test が import/load/execute するか” が読解上の条件になるため、ショートカットせず ANALYSIS 側に回す判断が安定する。

- ミニケース B（逆方向の誤判定を誘発しうる状況 + 悪化しない理由/回避策）:
  - 片方の変更が、relevant test が確実に load する設定/データ/モジュールの更新を欠落している状況（構造差が直接テスト結果に効く）。
  - 懸念: 「D1/D2 に必然的に効く」の表現が強すぎると、必然性の説明が面倒でショートカットが使いにくくなり、不要に ANALYSIS へ引き伸ばして判断が鈍る可能性。
  - 回避/悪化しない理由: After の例示（import/loads/executes）により “必然性” の判定を、既に S2 が扱う「relevant test の import 経路」へ揃えて言語化できる。新しい必須手順は増やさず、既存の S2 の範囲で説明可能。

## 一般的な推論品質への期待効果
- 減る失敗パターン:
  - 早期結論の短絡（premature commitment）
  - 「構造差＝意味差」という雑な同一視（根拠の飛躍）
  - compare での “decision criterion” の曖昧さ由来の一貫性欠如

## failed-approaches.md との整合（1〜2点だけ具体）
- 「探索をテンプレートで事前固定しすぎる変更は避ける」に整合:
  - 本提案は ‘探すべき証拠の種類’ を新しく固定しない。既存の D1/D2 の定義に沿って、早期結論の条件文を明確化するだけで、探索の自由度を狭めない。
- 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」に整合:
  - 新しい必須ゲートやチェック項目を増やさず、既存の早期結論許可文の表現を置換するのみ。

## 停滞対策の自己チェック（明記）
- 監査で褒められやすいが compare に効きにくい単なる整形/美文化に留まっていないか？
  - 留まっていない。STRUCTURAL TRIAGE の「早期に NOT_EQUIV へ進む」意思決定条件そのものを、D1/D2 スコープに接続して変更している。
- compare の誤判定（偽 EQUIV / 偽 NOT_EQUIV）を減らす“意思決定ポイント”が実際に変わるか？
  - 変わる。‘clear structural gap’ を見つけた瞬間に結論へ飛ぶのではなく、そのギャップが relevant tests に触れるか（D2）を満たすときだけショートカット可能、に変化する。
- 必須ゲート総量を増やしていないか？（置換/統合/削除による支払い）
  - 増やしていない。既存3行の文を、意味を明確化する言い換えに置換するだけで、新規必須手順や新規チェック欄は追加しない。

## 変更規模の宣言
- SKILL.md 変更は 5 行以内: STRUCTURAL TRIAGE 後の条件文を「表現置換（実質 3 行置換）」のみ。
