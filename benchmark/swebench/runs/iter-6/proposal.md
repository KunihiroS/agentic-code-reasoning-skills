# Iter-6 Proposal (focus_domain: overall)

## Exploration Framework
- カテゴリ: A. 推論の順序・構造を変える（強制）
- 今回選ぶメカニズム: 「結論から逆算して必要な証拠を特定する（逆方向推論）」を、`compare` の早期判断点（早期 NOT EQUIVALENT / EQUIVALENT 判断）に適用する。
- 理由: `compare` は最終的に「反例が存在するか/しないか」という判定に収束するが、現状のテンプレはその“反例形”の確定が遅く、構造差分を根拠にした早期 NOT EQUIVALENT だけが強く働きやすい。逆方向推論を前倒しして、探索の打ち切り条件をよりテスト関連性と反証可能性に寄せることで、全体の誤判定を減らす。

## 改善仮説（1つ בלבד）
`compare` で「反例の最小形（counterexample shape）」を先に言語化してから詳細分析に入るよう順序を前倒しし、かつ早期 NOT EQUIVALENT の条件を“関連テスト経路の確立”に明示的に結びつけると、(a) 関係ない構造差分での早計な NOT EQUIVALENT と、(b) 反例探索が弱いままの早計な EQUIVALENT の双方が減る。

## 現状ボトルネック診断（SKILL.md 自己引用 + 失敗メカニズム 1つ）
該当箇所（Compare / Certificate template）:

> "If S1 or S2 reveals a clear structural gap (missing file, missing module
> update, missing test data), you may proceed directly to FORMAL CONCLUSION
> with NOT EQUIVALENT without completing the full ANALYSIS section."

誘発される失敗メカニズム:
- 「構造差分が“関連テスト経路上の差分”であること」を十分に確立しないまま、早期 NOT EQUIVALENT が正当化されやすい（構造→結論の短絡）。この短絡は、誤 NOT_EQUIV（偽 NOT_EQUIV）を生みやすい一方で、EQUIV 側の“反例形”の具体化が遅くなるため偽 EQUIV も残りやすい。

## 停滞打破: Decision-point delta（IF/THEN 2行、行動が変わる条件を明示）
- Before: IF S1/S2 で構造差分が見える THEN 早期に NOT EQUIVALENT を結論しうる because 「構造差分 = 意味差分」型の根拠で打ち切れる。
- After:  IF S2 により“関連テストが import/exercise する経路上の欠落（file/module/test-data）”が確立できる THEN 早期に NOT EQUIVALENT、ELSE 反例の最小形を先に仮置きして ANALYSIS を継続 because 「テスト経路上での反例/反証」型の根拠で打ち切り/継続を分岐する。

対応する SKILL.md の見出し/セクション名:
- `## Compare` → `### Certificate template` → `STRUCTURAL TRIAGE (required before detailed tracing)`
- `## Compare` → `### Certificate template`（冒頭の「Complete every section...」行）

## 変更タイプ
- 並べ替え
- なぜ効くか: “何を探して結論を出すか”の順序を、(1) 反例形の仮置き（逆方向推論）→(2) 構造差分のテスト関連性の確立→(3) 詳細トレース、に寄せることで、探索の打ち切り判断が「見た目の差分」から「テストに現れる差分」へ移る。これは結論の質（compare の意思決定）を直接変える。

## SKILL.md のどこをどう変えるか（具体）
`Compare / Certificate template` の2点だけを、合計5行以内で差し替える:
1) 冒頭の指示文を「反例形（counterexample shape）を先に仮置きしてから ANALYSIS に入る」順序へ寄せる（逆方向推論の前倒し）。
2) 早期 NOT EQUIVALENT の許可条件を、S2 が要求している“関連テスト経路上”の確立に明示的に束縛する（構造差分の短絡を抑える）。

## 変更差分の最小プレビュー（必須: 同じ範囲を 3〜10 行、Before/After）
対象: `## Compare` → `### Certificate template`

Before:
```
### Certificate template

Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant
```

After:
```
### Certificate template

Complete every section; first sketch the minimal counterexample shape (reverse from D1), then use ANALYSIS to try to produce/refute it.

DEFINITIONS:
D1: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant
```

意思決定ポイントがどう変わるか（1行）:
- 「ANALYSIS に入ってから結論の根拠を探す」→「結論を崩す/支える最小反例を先に仮置きし、ANALYSIS を反例探索/反証として運用する」。

（同セクション内・早期結論条件の最小プレビュー）

Before:
```
If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```

After:
```
If S2 establishes a structural gap on a relevant test path (a file/module/test-data
that relevant tests import/exercise is missing), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.
```

## 期待される "挙動差"（compare に効く形）
- 変更前に起きがちな誤り（一般形）:
  - 「片側だけが触っているファイル/要素がある」ことをもって、関連テスト経路の確認が弱いまま NOT EQUIVALENT に倒す（偽 NOT_EQUIV）。
- 変更後にその誤りが減るメカニズム:
  - 早期 NOT EQUIVALENT の打ち切り条件が“関連テストが import/exercise する経路上の欠落”に結びつくため、関係ない差分では打ち切りづらくなる。
- その結果として減る誤判定（片方向最適化にならない形で）:
  - 主に偽 NOT_EQUIV が減る見込み。加えて、反例形を先に仮置きするため「反例探索が弱いまま EQUIVALENT と言い切る」タイプの偽 EQUIV も減らしやすい（両方向のバランスを維持）。

## 最小インパクト検証（思考実験で可）
- ミニケース A（変更前は揺れる/誤るが変更後は安定）:
  - 2つの実装が“同じテストを通す”かどうかが、特定の入力条件（境界値・例外経路など）でのみ分岐しうる状況。変更前は、詳細トレースを進めても「どの分岐を反証すべきか」が曖昧で、EQUIVALENT 側の反例提示が形式化しやすい。変更後は、先に最小反例形を置くことで、ANALYSIS がその反例の生成/反証に向き、結論が安定する。
- ミニケース B（逆方向の誤判定を誘発しうる状況 + 悪化しない理由/回避）:
  - 反例形の仮置きが強すぎると、別種の差分（反例形に現れないがテスト結果を変える差分）を見落として偽 EQUIV を増やしうる。
  - 悪化しない理由/回避策（新しい必須手順は増やさない）:
    - ここでの変更は「反例形を固定して探索を狭める」ではなく「最小反例形を“仮置きして更新する”」であり、既存の Step 5（Refutation check）と Guardrail #4（差分を見つけたらテスト経路で追う）が探索の多様性を担保する。つまり、反例形は探索の開始点であって拘束条件ではない。

## failed-approaches.md との整合（1〜2点だけ具体）
- 「探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」に整合: 本提案は“証拠の種類”を追加固定せず、既に必須な D1/ANALYSIS/反証の枠内で「反例形を先に仮置きする」という順序のみを変える。
- 「読解順序の半固定は探索経路を早期に細らせうる」に対する配慮: 反例形は「更新前提の仮置き」として明記し、早期に探索経路を1本化する指示ではない（探索自由度を削りすぎない）。

## 変更規模の宣言
- SKILL.md 変更は最大 5 行以内（置換中心）。新しい必須ゲートの増設なし。

## 停滞対策の自己チェック（明記）
- これは「監査で褒められやすいが compare には効きにくい」整形だけか？
  - いいえ。早期 NOT EQUIVALENT の打ち切り条件と、ANALYSIS 開始前の思考順序（反例形の仮置き）という“結論の出し方”を直接変える。
- compare の誤判定（偽 EQUIV / 偽 NOT_EQUIV）を減らす意思決定ポイントが実際に変わるか？
  - はい。「構造差分を見たら結論に倒す/詳細へ進む」の分岐が、関連テスト経路の確立に依存するよう変わる。また、ANALYSIS の運用が「反例探索/反証」へ寄る。
- Decision-point delta の Before/After は、条件も行動も同じで理由だけの言い換えになっていないか？
  - なっていない。After は“関連テスト経路が確立できない限り早期 NOT EQUIVALENT に倒さない”という条件・行動の両方が変わる。
- 必須ゲート総量を増やしていないか？
  - 増やしていない。既存の節（Compare / Certificate template）内の表現置換で、必須手順の追加は行わない。
